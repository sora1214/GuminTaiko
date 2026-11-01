#include "WordList.hpp"

#include "DataTable.hpp"
#include "raylib.h"

namespace {

constexpr const char* kWordListPath = "Data/x64/datatable/wordlist.bin";

} // namespace

const std::string& WordList::Text(const std::string& key) {
    if (!loaded_) Load();
    if (auto found = overrides_.find(key); found != overrides_.end()) return found->second;
    if (auto found = words_.find(key); found != words_.end()) return found->second;
    return key;
}

void WordList::Load() {
    loaded_ = true;

    // {"items":[ {"key":"...", "japaneseText":"...", ...}, ... ]}
    for (const DataTable::Item& item : DataTable::Load(kWordListPath)) {
        const std::string& key = item.Text("key");
        if (!key.empty()) words_[key] = item.Text("japaneseText");
    }
    TraceLog(LOG_INFO, "WordList: %zu 件読み込みました", words_.size());
}
