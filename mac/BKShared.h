// Process-wide state shared by every input controller: the phonetic
// suggester (dictionaries are loaded once), the Bangla/English mode, and the
// per-user learned-word file.
#pragma once

#import <Cocoa/Cocoa.h>

#include <string>
#include <vector>

#define BK_BUNDLE_ID @"io.github.amerganim.inputmethod.AmaderBanglaKeyboard"
#define BK_MODE_ID BK_BUNDLE_ID @".Bangla"
#define BK_CONNECTION_NAME @"AmaderBanglaKeyboard_Connection"

namespace bk {

// Loads the bundled dictionary.tsv / words.tsv and the user's learned.tsv the
// first time it is called. Safe to call repeatedly.
void EnsureLoaded();

// Literal transliteration (smart conjuncts), as UTF-8.
std::string Transliterate(const std::string& roman);

// Suggestions for the romanized prefix; element 0 is the literal
// transliteration.
std::vector<std::string> Suggest(const std::string& roman, size_t max = 9);

// Remember that the user picked `bangla` and persist the learned data
// (debounced).
void RecordUsage(const std::string& bangla);

// Flush learned data to disk now.
void SaveLearned();

// Bangla (true) vs. English pass-through (false). Session-only: the process
// always starts in Bangla mode.
bool BanglaEnabled();
void SetBanglaEnabled(bool enabled);

}  // namespace bk

NSString* BKString(const std::string& utf8);
