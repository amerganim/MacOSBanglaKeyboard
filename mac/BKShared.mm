#import "BKShared.h"

#include <fstream>
#include <iterator>
#include <mutex>

#include "bnphonetic/Suggester.h"
#include "bnphonetic/Transliterator.h"

namespace {

bnphonetic::Suggester* g_suggester = nullptr;
std::once_flag g_once;
bool g_enabled = true;
bool g_save_pending = false;

std::string ReadFile(NSString* path) {
  if (path == nil) return std::string();
  std::ifstream f(path.fileSystemRepresentation, std::ios::binary);
  if (!f) return std::string();
  return std::string((std::istreambuf_iterator<char>(f)),
                     std::istreambuf_iterator<char>());
}

// ~/Library/Application Support/AmaderBanglaKeyboard
NSString* UserDataDir() {
  NSArray<NSString*>* dirs = NSSearchPathForDirectoriesInDomains(
      NSApplicationSupportDirectory, NSUserDomainMask, YES);
  if (dirs.count == 0) return nil;
  return [dirs[0] stringByAppendingPathComponent:@"AmaderBanglaKeyboard"];
}

NSString* LearnedPath() {
  return [UserDataDir() stringByAppendingPathComponent:@"learned.tsv"];
}

}  // namespace

NSString* BKString(const std::string& utf8) {
  NSString* s = [[NSString alloc] initWithBytes:utf8.data()
                                         length:utf8.size()
                                       encoding:NSUTF8StringEncoding];
  return s ?: @"";
}

namespace bk {

void EnsureLoaded() {
  std::call_once(g_once, [] {
    g_suggester = new bnphonetic::Suggester();
    NSBundle* bundle = [NSBundle mainBundle];
    const std::string dict =
        ReadFile([bundle pathForResource:@"dictionary" ofType:@"tsv"]);
    if (!dict.empty()) g_suggester->LoadDictionaryData(dict);
    const std::string words =
        ReadFile([bundle pathForResource:@"words" ofType:@"tsv"]);
    if (!words.empty()) g_suggester->LoadWordList(words);
    const std::string learned = ReadFile(LearnedPath());
    if (!learned.empty()) g_suggester->LoadLearnedData(learned);
  });
}

std::string Transliterate(const std::string& roman) {
  return bnphonetic::Transliterate(roman, /*smart=*/true);
}

std::vector<std::string> Suggest(const std::string& roman, size_t max) {
  EnsureLoaded();
  return g_suggester->Suggest(roman, max, /*smart=*/true);
}

void RecordUsage(const std::string& bangla) {
  EnsureLoaded();
  g_suggester->RecordUsage(bangla);
  if (g_save_pending) return;
  g_save_pending = true;
  // Debounce: coalesce several picks into one write.
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
                 dispatch_get_main_queue(), ^{
                   SaveLearned();
                 });
}

void SaveLearned() {
  g_save_pending = false;
  if (g_suggester == nullptr) return;
  NSString* dir = UserDataDir();
  if (dir == nil) return;
  [[NSFileManager defaultManager] createDirectoryAtPath:dir
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
  const std::string data = g_suggester->DumpLearnedData();
  NSData* bytes = [NSData dataWithBytes:data.data() length:data.size()];
  [bytes writeToFile:LearnedPath() atomically:YES];
}

bool BanglaEnabled() { return g_enabled; }
void SetBanglaEnabled(bool enabled) { g_enabled = enabled; }

}  // namespace bk
