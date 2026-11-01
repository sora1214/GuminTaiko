#include "Json.hpp"

#include <cmath>
#include <cstdio>
#include <cstdlib>

namespace Json {

namespace {

const Value kNull;

class Parser {
public:
    explicit Parser(const std::string& text) : s_(text) {}

    bool Run(Value& out, std::string* error) {
        // 手で書いたファイルの UTF-8 の BOM は飛ばす
        if (s_.compare(0, 3, "\xEF\xBB\xBF") == 0) pos_ = 3;
        if (!ParseValue(out) || (SkipSpace(), pos_ != s_.size())) {
            if (error) *error = error_.empty() ? "JSON の後ろに余計な文字があります（" + std::to_string(pos_) + " 文字目）" : error_;
            return false;
        }
        return true;
    }

private:
    bool Fail(const std::string& message) {
        if (error_.empty()) error_ = message + "（" + std::to_string(pos_) + " 文字目）";
        return false;
    }

    void SkipSpace() {
        while (pos_ < s_.size() && (s_[pos_] == ' ' || s_[pos_] == '\t' || s_[pos_] == '\n' || s_[pos_] == '\r')) ++pos_;
    }

    bool Literal(const char* word) {
        const std::string w(word);
        if (s_.compare(pos_, w.size(), w) != 0) return false;
        pos_ += w.size();
        return true;
    }

    bool ParseValue(Value& out) {
        if (++depth_ > 64) return Fail("入れ子が深すぎます");
        SkipSpace();
        bool ok = false;
        if (pos_ >= s_.size()) {
            ok = Fail("値がありません");
        } else if (s_[pos_] == '{') {
            ok = ParseObject(out);
        } else if (s_[pos_] == '[') {
            ok = ParseArray(out);
        } else if (s_[pos_] == '"') {
            std::string str;
            ok = ParseString(str);
            if (ok) out = Value(std::move(str));
        } else if (Literal("true")) {
            out = Value(true);
            ok = true;
        } else if (Literal("false")) {
            out = Value(false);
            ok = true;
        } else if (Literal("null")) {
            out = Value();
            ok = true;
        } else {
            ok = ParseNumber(out);
        }
        --depth_;
        return ok;
    }

    bool ParseObject(Value& out) {
        out = Value::MakeObject();
        ++pos_;
        SkipSpace();
        if (pos_ < s_.size() && s_[pos_] == '}') {
            ++pos_;
            return true;
        }
        while (true) {
            SkipSpace();
            std::string key;
            if (pos_ >= s_.size() || s_[pos_] != '"' || !ParseString(key)) return Fail("オブジェクトのキーがありません");
            SkipSpace();
            if (pos_ >= s_.size() || s_[pos_] != ':') return Fail("':' がありません");
            ++pos_;
            Value value;
            if (!ParseValue(value)) return false;
            out[key] = std::move(value);
            SkipSpace();
            if (pos_ < s_.size() && s_[pos_] == ',') {
                ++pos_;
                continue;
            }
            if (pos_ < s_.size() && s_[pos_] == '}') {
                ++pos_;
                return true;
            }
            return Fail("',' か '}' がありません");
        }
    }

    bool ParseArray(Value& out) {
        out = Value::MakeArray();
        ++pos_;
        SkipSpace();
        if (pos_ < s_.size() && s_[pos_] == ']') {
            ++pos_;
            return true;
        }
        while (true) {
            Value value;
            if (!ParseValue(value)) return false;
            out.Push(std::move(value));
            SkipSpace();
            if (pos_ < s_.size() && s_[pos_] == ',') {
                ++pos_;
                continue;
            }
            if (pos_ < s_.size() && s_[pos_] == ']') {
                ++pos_;
                return true;
            }
            return Fail("',' か ']' がありません");
        }
    }

    static void AppendUtf8(std::string& out, unsigned cp) {
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

    bool ReadHex4(unsigned& out) {
        if (pos_ + 4 > s_.size()) return false;
        out = 0;
        for (int i = 0; i < 4; ++i) {
            const char c = s_[pos_++];
            out <<= 4;
            if (c >= '0' && c <= '9') out |= unsigned(c - '0');
            else if (c >= 'a' && c <= 'f') out |= unsigned(c - 'a' + 10);
            else if (c >= 'A' && c <= 'F') out |= unsigned(c - 'A' + 10);
            else return false;
        }
        return true;
    }

    bool ParseString(std::string& out) {
        ++pos_;   // "
        while (pos_ < s_.size()) {
            const char c = s_[pos_++];
            if (c == '"') return true;
            if (c != '\\') {
                out += c;
                continue;
            }
            if (pos_ >= s_.size()) break;
            const char e = s_[pos_++];
            switch (e) {
            case '"': out += '"'; break;
            case '\\': out += '\\'; break;
            case '/': out += '/'; break;
            case 'b': out += '\b'; break;
            case 'f': out += '\f'; break;
            case 'n': out += '\n'; break;
            case 'r': out += '\r'; break;
            case 't': out += '\t'; break;
            case 'u': {
                unsigned cp = 0;
                if (!ReadHex4(cp)) return Fail("\\u の後ろが16進数ではありません");
                // サロゲートペア
                if (cp >= 0xD800 && cp <= 0xDBFF && s_.compare(pos_, 2, "\\u") == 0) {
                    pos_ += 2;
                    unsigned low = 0;
                    if (!ReadHex4(low)) return Fail("\\u の後ろが16進数ではありません");
                    cp = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00);
                }
                AppendUtf8(out, cp);
                break;
            }
            default: return Fail("知らないエスケープです");
            }
        }
        return Fail("文字列が閉じていません");
    }

    bool ParseNumber(Value& out) {
        const char* begin = s_.c_str() + pos_;
        char* end = nullptr;
        const double n = std::strtod(begin, &end);
        if (end == begin) return Fail("値として読めません");
        pos_ += size_t(end - begin);
        out = Value(n);
        return true;
    }

    const std::string& s_;
    size_t pos_ = 0;
    int depth_ = 0;
    std::string error_;
};

void DumpString(const std::string& s, std::string& out) {
    out += '"';
    for (const char c : s) {
        switch (c) {
        case '"': out += "\\\""; break;
        case '\\': out += "\\\\"; break;
        case '\n': out += "\\n"; break;
        case '\r': out += "\\r"; break;
        case '\t': out += "\\t"; break;
        default:
            if (static_cast<unsigned char>(c) < 0x20) {
                char buf[8];
                std::snprintf(buf, sizeof(buf), "\\u%04x", unsigned(static_cast<unsigned char>(c)));
                out += buf;
            } else {
                out += c;
            }
        }
    }
    out += '"';
}

void DumpValue(const Value& v, int indent, int level, std::string& out) {
    const std::string pad(size_t(indent * (level + 1)), ' ');
    const std::string padEnd(size_t(indent * level), ' ');
    switch (v.GetType()) {
    case Value::Type::Null: out += "null"; break;
    case Value::Type::Bool: out += v.AsBool() ? "true" : "false"; break;
    case Value::Type::Number: {
        const double n = v.AsNumber();
        char buf[32];
        if (std::floor(n) == n && std::fabs(n) < 1e15) std::snprintf(buf, sizeof(buf), "%.0f", n);
        else {
            // 読み戻して同じ値になるいちばん短い書き方（1.2 を 1.1999999999999999 と書かない）
            std::snprintf(buf, sizeof(buf), "%.15g", n);
            if (std::strtod(buf, nullptr) != n) std::snprintf(buf, sizeof(buf), "%.17g", n);
        }
        out += buf;
        break;
    }
    case Value::Type::String: DumpString(v.AsString(), out); break;
    case Value::Type::Array: {
        if (v.Items().empty()) {
            out += "[]";
            break;
        }
        out += "[\n";
        for (size_t i = 0; i < v.Items().size(); ++i) {
            out += pad;
            DumpValue(v.Items()[i], indent, level + 1, out);
            out += i + 1 < v.Items().size() ? ",\n" : "\n";
        }
        out += padEnd + "]";
        break;
    }
    case Value::Type::Object: {
        if (v.Members().empty()) {
            out += "{}";
            break;
        }
        out += "{\n";
        for (size_t i = 0; i < v.Members().size(); ++i) {
            out += pad;
            DumpString(v.Members()[i].first, out);
            out += ": ";
            DumpValue(v.Members()[i].second, indent, level + 1, out);
            out += i + 1 < v.Members().size() ? ",\n" : "\n";
        }
        out += padEnd + "}";
        break;
    }
    }
}

} // namespace

const Value& Value::operator[](const std::string& key) const {
    for (const auto& member : members_) {
        if (member.first == key) return member.second;
    }
    return kNull;
}

Value& Value::operator[](const std::string& key) {
    if (type_ != Type::Object) *this = MakeObject();
    for (auto& member : members_) {
        if (member.first == key) return member.second;
    }
    members_.emplace_back(key, Value());
    return members_.back().second;
}

bool Value::Has(const std::string& key) const {
    for (const auto& member : members_) {
        if (member.first == key) return true;
    }
    return false;
}

void Value::Push(Value value) {
    if (type_ != Type::Array) *this = MakeArray();
    items_.push_back(std::move(value));
}

bool Parse(const std::string& text, Value& out, std::string* error) {
    Parser parser(text);
    return parser.Run(out, error);
}

std::string Dump(const Value& value, int indent) {
    std::string out;
    DumpValue(value, indent, 0, out);
    out += '\n';
    return out;
}

} // namespace Json
