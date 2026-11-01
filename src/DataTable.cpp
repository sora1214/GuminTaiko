#include "DataTable.hpp"

#include <cstdlib>
#include "raylib.h"

namespace DataTable {

namespace {

void AppendUtf8(std::string& out, unsigned int cp) {
    if (cp < 0x80) {
        out += char(cp);
    } else if (cp < 0x800) {
        out += char(0xC0 | (cp >> 6));
        out += char(0x80 | (cp & 0x3F));
    } else if (cp < 0x10000) {
        out += char(0xE0 | (cp >> 12));
        out += char(0x80 | ((cp >> 6) & 0x3F));
        out += char(0x80 | (cp & 0x3F));
    } else {
        out += char(0xF0 | (cp >> 18));
        out += char(0x80 | ((cp >> 12) & 0x3F));
        out += char(0x80 | ((cp >> 6) & 0x3F));
        out += char(0x80 | (cp & 0x3F));
    }
}

bool IsSpace(char c) { return c == ' ' || c == '\n' || c == '\r' || c == '\t'; }

void SkipSpace(const std::string& json, size_t& pos) {
    while (pos < json.size() && IsSpace(json[pos])) ++pos;
}

} // namespace

// gzip のヘッダーとフッターを外して DEFLATE を展開する
std::string Gunzip(const unsigned char* data, int size) {
    if (size < 18 || data[0] != 0x1F || data[1] != 0x8B || data[2] != 8) return {};

    const unsigned char flags = data[3];
    int pos = 10;
    if (flags & 0x04) pos += 2 + (data[pos] | (data[pos + 1] << 8));   // FEXTRA
    if (flags & 0x08) while (pos < size && data[pos++] != 0) {}         // FNAME
    if (flags & 0x10) while (pos < size && data[pos++] != 0) {}         // FCOMMENT
    if (flags & 0x02) pos += 2;                                         // FHCRC
    if (pos >= size - 8) return {};

    int outSize = 0;
    unsigned char* out = DecompressData(data + pos, size - pos - 8, &outSize);
    if (!out) return {};
    std::string result(reinterpret_cast<char*>(out), size_t(outSize));
    MemFree(out);
    return result;
}

std::string ReadJsonString(const std::string& json, size_t& pos) {
    std::string out;
    if (pos >= json.size() || json[pos] != '"') return out;
    ++pos;
    while (pos < json.size() && json[pos] != '"') {
        char c = json[pos++];
        if (c != '\\' || pos >= json.size()) {
            out += c;
            continue;
        }
        c = json[pos++];
        switch (c) {
        case 'n': out += '\n'; break;
        case 't': out += '\t'; break;
        case 'r': break;
        case 'u': {
            unsigned int cp = unsigned(std::stoul(json.substr(pos, 4), nullptr, 16));
            pos += 4;
            // サロゲートペア
            if (cp >= 0xD800 && cp <= 0xDBFF && json.compare(pos, 2, "\\u") == 0) {
                const unsigned int low = unsigned(std::stoul(json.substr(pos + 2, 4), nullptr, 16));
                cp = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00);
                pos += 6;
            }
            AppendUtf8(out, cp);
            break;
        }
        default: out += c; break;
        }
    }
    ++pos;
    return out;
}

const std::string& Item::Text(const std::string& key) const {
    static const std::string kEmpty;
    auto found = values.find(key);
    return found != values.end() ? found->second : kEmpty;
}

int Item::Int(const std::string& key, int fallback) const {
    const std::string& text = Text(key);
    if (text.empty()) return fallback;
    return std::atoi(text.c_str());
}

std::vector<Item> Load(const std::string& path) {
    std::vector<Item> items;
    int size = 0;
    unsigned char* data = LoadFileData(path.c_str(), &size);
    if (!data) return items;
    const std::string json = Gunzip(data, size);
    UnloadFileData(data);
    if (json.empty()) {
        TraceLog(LOG_WARNING, "DataTable: %s を展開できません", path.c_str());
        return items;
    }

    // "items" の配列の中の { ... } を順に読む
    size_t pos = json.find("\"items\"");
    if (pos == std::string::npos) return items;
    pos = json.find('[', pos);
    if (pos == std::string::npos) return items;
    ++pos;
    while (true) {
        SkipSpace(json, pos);
        if (pos >= json.size() || json[pos] == ']') break;
        if (json[pos] == ',') {
            ++pos;
            continue;
        }
        if (json[pos] != '{') break;
        ++pos;

        Item item;
        while (true) {
            SkipSpace(json, pos);
            if (pos >= json.size()) break;
            if (json[pos] == '}') {
                ++pos;
                break;
            }
            if (json[pos] == ',') {
                ++pos;
                continue;
            }
            const std::string key = ReadJsonString(json, pos);
            SkipSpace(json, pos);
            if (pos < json.size() && json[pos] == ':') ++pos;
            SkipSpace(json, pos);
            std::string value;
            if (pos < json.size() && json[pos] == '"') {
                value = ReadJsonString(json, pos);
            } else {
                const size_t start = pos;
                while (pos < json.size() && json[pos] != ',' && json[pos] != '}' && !IsSpace(json[pos])) ++pos;
                value = json.substr(start, pos - start);
            }
            item.values[key] = std::move(value);
        }
        items.push_back(std::move(item));
    }
    return items;
}

} // namespace DataTable
