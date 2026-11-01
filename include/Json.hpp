#pragma once
#include <string>
#include <utility>
#include <vector>

// 小さな JSON（プレイヤーデータの保存用）。オブジェクトはキーの順を保つ
namespace Json {

class Value {
public:
    enum class Type { Null, Bool, Number, String, Array, Object };

    Value() = default;
    Value(bool b) : type_(Type::Bool), bool_(b) {}
    Value(int n) : type_(Type::Number), number_(n) {}
    Value(double n) : type_(Type::Number), number_(n) {}
    Value(const char* s) : type_(Type::String), string_(s) {}
    Value(std::string s) : type_(Type::String), string_(std::move(s)) {}
    static Value MakeArray() { Value v; v.type_ = Type::Array; return v; }
    static Value MakeObject() { Value v; v.type_ = Type::Object; return v; }

    Type GetType() const { return type_; }
    bool IsNull() const { return type_ == Type::Null; }
    bool IsObject() const { return type_ == Type::Object; }
    bool IsArray() const { return type_ == Type::Array; }

    // 型が違う・無いときは fallback
    bool AsBool(bool fallback = false) const { return type_ == Type::Bool ? bool_ : fallback; }
    double AsNumber(double fallback = 0.0) const { return type_ == Type::Number ? number_ : fallback; }
    int AsInt(int fallback = 0) const { return type_ == Type::Number ? int(number_) : fallback; }
    std::string AsString(const std::string& fallback = "") const { return type_ == Type::String ? string_ : fallback; }

    // オブジェクト: 無いキーは null を返す（const）／作って返す（非 const）
    const Value& operator[](const std::string& key) const;
    Value& operator[](const std::string& key);
    bool Has(const std::string& key) const;
    const std::vector<std::pair<std::string, Value>>& Members() const { return members_; }

    // 配列
    const std::vector<Value>& Items() const { return items_; }
    void Push(Value value);

private:
    Type type_ = Type::Null;
    bool bool_ = false;
    double number_ = 0.0;
    std::string string_;
    std::vector<Value> items_;
    std::vector<std::pair<std::string, Value>> members_;
};

// UTF-8 の JSON 文字列を読む。失敗したら false（error に理由）
bool Parse(const std::string& text, Value& out, std::string* error = nullptr);
// 字下げつきで書く（日本語はそのまま UTF-8）
std::string Dump(const Value& value, int indent = 2);

} // namespace Json
