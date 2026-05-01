#!/bin/bash
# wx2.6 → wx3 source compatibility patches for TreeMaker 5.
# Run from /src/linux after cloning the repo.
# Safe to re-run: resets source tree to clean state first.
set -e

# Reset to unmodified upstream so patches are idempotent.
(cd /src && git checkout .)

S=../Source   # path to Source tree from linux/

# ── Makefile ──────────────────────────────────────────────────────────────────
# gtk+-2.0 → gtk+-3.0 (wx3 uses GTK3 backend on Ubuntu 22.04)
sed -i 's/gtk+-2\.0/gtk+-3.0/g' Makefile

# -fpermissive: unqualified inherited names in templates (contains, push_back,
# erase, insert) are errors in C++11 two-phase lookup. -fpermissive demotes to
# warnings.
sed -i 's/^OPTIONS =/OPTIONS = -fpermissive/' Makefile

# Modern ld requires explicit DSO listing; gtk_main_iteration lives in
# libgtk-3 but wx-config --libs doesn't pull it in directly on Ubuntu 22.04.
sed -i 's|`\$(WXCONFIG) --libs`|& `pkg-config --libs gtk+-3.0`|g' Makefile

# ── tmwxApp.h ─────────────────────────────────────────────────────────────────
# wxPageSetupDialogData lives in wx/cmndata.h. Include ordering means it isn't
# visible when tmwxApp.h is parsed. Inject the include right after tmHeader.h.
sed -i 's|#include "tmHeader.h"|#include "tmHeader.h"\n#include <wx/cmndata.h>|' \
    "$S/tmwxGUI/tmwxCommon/tmwxApp.h"

# wxPageSetupData is a #define in wx3; replace with the actual class name so
# the include above satisfies it unconditionally.
sed -i 's/wxPageSetupData/wxPageSetupDialogData/g' \
    "$S/tmwxGUI/tmwxCommon/tmwxApp.h" \
    "$S/tmwxGUI/tmwxCommon/tmwxApp.cpp"

# ── tmwxHtmlHelpController ────────────────────────────────────────────────────
# CreateHelpWindow() returns wxWindow* in wx3 (was void in wx2.6).
sed -i 's/void CreateHelpWindow();/wxWindow* CreateHelpWindow();/' \
    "$S/tmwxGUI/tmwxHtmlHelp/tmwxHtmlHelpController.h"

sed -i 's/void tmwxHtmlHelpController::CreateHelpWindow()/wxWindow* tmwxHtmlHelpController::CreateHelpWindow()/' \
    "$S/tmwxGUI/tmwxHtmlHelp/tmwxHtmlHelpController.cpp"

sed -i 's|  wxHtmlHelpController::CreateHelpWindow();|  return wxHtmlHelpController::CreateHelpWindow();|' \
    "$S/tmwxGUI/tmwxHtmlHelp/tmwxHtmlHelpController.cpp"

# ── tmwxApp.cpp ───────────────────────────────────────────────────────────────
# wxT() is a string-literal macro in wx3 (L##x). Cannot wrap runtime char* or
# wxString expressions.
sed -i 's/prefix = wxT (p);/prefix = wxString::FromUTF8(p);/' \
    "$S/tmwxGUI/tmwxCommon/tmwxApp.cpp"
sed -i 's|mConfig.mDocIcon.LoadFile (wxT (mDataDir + "/Icon_doc_48.png"));|mConfig.mDocIcon.LoadFile(mDataDir + "/Icon_doc_48.png");|' \
    "$S/tmwxGUI/tmwxCommon/tmwxApp.cpp"
sed -i 's|mConfig.mAppIcon.LoadFile (wxT (mDataDir + "/Icon_app_48.png"));|mConfig.mAppIcon.LoadFile(mDataDir + "/Icon_app_48.png");|' \
    "$S/tmwxGUI/tmwxCommon/tmwxApp.cpp"

# wxWindow::ProcessEvent() is protected in wx3; public API is ProcessWindowEvent().
sed -i 's/topWindow->ProcessEvent(event)/topWindow->ProcessWindowEvent(event)/' \
    "$S/tmwxGUI/tmwxCommon/tmwxApp.cpp"

# wxConfigBase::Write<T> uses wxToString(T) in wx3; no overload for enum.
sed -i 's/wxConfig::Get()->Write(ALGORITHM_KEY, algorithm);/wxConfig::Get()->Write(ALGORITHM_KEY, (long)algorithm);/' \
    "$S/tmwxGUI/tmwxCommon/tmwxApp.cpp"

# ── tmArray.h / tmDpptrArray.h ───────────────────────────────────────────────
# GCC 13 two-phase lookup no longer demoted by -fpermissive: inherited names
# in template methods must be qualified with this->.

# assign_all (inline in class body)
sed -i 's/{assign(this->size(), t);}}/{this->assign(this->size(), t);}/' \
    "$S/tmModel/tmPtrClasses/tmArray.h"

# push_front, InsertItemAt, merge_with: all unqualified insert(this->...)
sed -i 's/  insert(this->/  this->insert(this->/g' \
    "$S/tmModel/tmPtrClasses/tmArray.h"

# union_with(const T&): push_back
sed -i 's/== this->end()) push_back(t);/== this->end()) this->push_back(t);/' \
    "$S/tmModel/tmPtrClasses/tmArray.h"

# RemoveItemAt: erase(this->begin() + ...)
sed -i 's/  erase(this->begin() + ptrdiff_t/  this->erase(this->begin() + ptrdiff_t/' \
    "$S/tmModel/tmPtrClasses/tmArray.h"

# erase_remove: erase(remove(...))
sed -i 's/  erase(remove(/  this->erase(remove(/' \
    "$S/tmModel/tmPtrClasses/tmArray.h"

# rotate_left: erase(this->begin())
sed -i 's/  erase(this->begin());/  this->erase(this->begin());/' \
    "$S/tmModel/tmPtrClasses/tmArray.h"

# rotate_right: erase(rbegin()) is invalid — use pop_back()
sed -i 's/  erase(this->rbegin());/  this->pop_back();/' \
    "$S/tmModel/tmPtrClasses/tmArray.h"

# tmDpptrArray: contains and push_back in union_with / erase_remove
sed -i 's/if (!contains(pt)) push_back(pt);/if (!this->contains(pt)) this->push_back(pt);/' \
    "$S/tmModel/tmPtrClasses/tmDpptrArray.h"
sed -i 's/  if (contains(pt)) {/  if (this->contains(pt)) {/' \
    "$S/tmModel/tmPtrClasses/tmDpptrArray.h"

# ── tmwxDesignCanvas.cpp ──────────────────────────────────────────────────────
# GetPrintableName removed in wx3.2; GetUserReadableName() returns wxString.
sed -i 's/mDoc->GetPrintableName(text);/text = mDoc->GetUserReadableName();/' \
    "$S/tmwxGUI/tmwxDocView/tmwxDesignCanvas.cpp"
# Same removal; called on `this` in tmwxDoc_File.cpp
sed -i 's/GetPrintableName(pname);/pname = GetUserReadableName();/' \
    "$S/tmwxGUI/tmwxDocView/tmwxDoc_File.cpp"

# ── tmHeader.cpp ─────────────────────────────────────────────────────────────
# In wx3, wxString::c_str() returns wxCStrData, which converts to both
# const wchar_t* and const char*. The unicode bridge overload creates an
# ambiguous call when it passes strX.c_str() back to the primary overload.
# wx3 is unicode-only, so the bridge is dead code — delete it.
sed -i '/#if defined(wxUSE_UNICODE) && wxUSE_UNICODE/,/#endif \/\/ wxUSE_UNICODE/d' \
    "$S/tmHeader.cpp"

# ── tmwxDesignFrame.cpp ───────────────────────────────────────────────────────
# wxDocChildFrameAny::OnActivate is private in wx3; cannot call from derived class.
sed -i '/tmwxDocChildFrame::OnActivate(event);/d' \
    "$S/tmwxGUI/tmwxDocView/tmwxDesignFrame.cpp"

# ── wxFileDialog style flags renamed in wx3 ───────────────────────────────────
# Old names were plain constants; wx3 uses wxFD_* prefixed versions.
# Applied globally across the GUI source tree.
find "$S/tmwxGUI" -name '*.cpp' -o -name '*.h' | xargs sed -i \
    -e 's/\bwxSAVE\b/wxFD_SAVE/g' \
    -e 's/\bwxOPEN\b/wxFD_OPEN/g' \
    -e 's/\bwxOVERWRITE_PROMPT\b/wxFD_OVERWRITE_PROMPT/g' \
    -e 's/\bwxFILE_MUST_EXIST\b/wxFD_FILE_MUST_EXIST/g' \
    -e 's/\bwxMULTIPLE\b/wxFD_MULTIPLE/g' \
    -e 's/\bwxHIDE_READONLY\b/wxFD_NO_FOLLOW/g' \
    -e 's/\bwxCHANGE_DIR\b/wxFD_CHANGE_DIR/g'

# ── tmwxHtmlHelpFrame ─────────────────────────────────────────────────────────
# wx3 removed m_Printer from wxHtmlHelpFrame and renamed m_HtmlWin →
# m_HtmlHelpWin (which is wxHtmlHelpWindow*; call GetHtmlWindow() to reach
# the underlying wxHtmlWindow). Add mPrinter as our own member instead.

# Add private member + htmprint include to header.
sed -i 's|#include "wx/html/helpfrm.h"|#include "wx/html/helpfrm.h"\n#include <wx/html/htmprint.h>|' \
    "$S/tmwxGUI/tmwxHtmlHelp/tmwxHtmlHelpFrame.h"
sed -i 's/  DECLARE_EVENT_TABLE()/  DECLARE_EVENT_TABLE()\nprivate:\n  wxHtmlEasyPrinting* mPrinter;/' \
    "$S/tmwxGUI/tmwxHtmlHelp/tmwxHtmlHelpFrame.h"

# Initialize mPrinter in constructor.
sed -i 's/  wxHtmlHelpFrame(data)/  wxHtmlHelpFrame(data),\n  mPrinter(NULL)/' \
    "$S/tmwxGUI/tmwxHtmlHelp/tmwxHtmlHelpFrame.cpp"

# Replace base-class member references.
sed -i 's/m_Printer/mPrinter/g' \
    "$S/tmwxGUI/tmwxHtmlHelp/tmwxHtmlHelpFrame.cpp"
sed -i 's/m_HtmlWin/m_HtmlHelpWin->GetHtmlWindow()/g' \
    "$S/tmwxGUI/tmwxHtmlHelp/tmwxHtmlHelpFrame.cpp"

# wxHtmlHelpFrame::OnActivate is also private in wx3.
sed -i '/wxHtmlHelpFrame::OnActivate(event);/d' \
    "$S/tmwxGUI/tmwxHtmlHelp/tmwxHtmlHelpFrame.cpp"

# ── tmwxOptimizerDialog_gtk.cpp ───────────────────────────────────────────────
# m_modalShowing was protected in wx2.6; became private in wx3.
# Code was lifted verbatim from wxGTK 2.5.1 internals — remove the direct
# member access; dialog show/hide still works without it.
sed -i '/m_modalShowing = true;/d' \
    "$S/tmwxGUI/tmwxOptimizerDialog/tmwxOptimizerDialog_gtk.cpp"

# g_openDialogs was a wxGTK 2.5 internal symbol; it no longer exists in wx3.
# Define a local stub so the file compiles and links without it.
sed -i 's/extern int g_openDialogs;/static int g_openDialogs = 0;/' \
    "$S/tmwxGUI/tmwxOptimizerDialog/tmwxOptimizerDialog_gtk.cpp"

echo "All patches applied."
