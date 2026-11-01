-- 段位選択画面.グローバル変数Lua
-- Masayuki_Teraoka@al.bandainamco.jp

-- 対応するlumenファイル
UseLumenFile = "lumen/000_default/enso_dani/dani_select/dani_select"

-- --=== 定数
kSongDataTypeSong =	0 					---- 曲パネル

play_data_ = 0 							-- 各ユーザーの過去プレイデータ記録(王冠・スコアランク・段位情報など)
user_setting_Original_data_ = {}		-- ユーザーのデフォルト演奏設定

-- --=== グローバル変数
-- -- 結果
nextMode = -1							-- 遷移先

is_joinLeft = false
is_joinRight = false

-- プレイヤーの現在の段位
playerNowRank = 1

-- プレイヤーデータのアップデートフラグ
is_userDataUpdate = false

-- 最後に選択した曲の情報(in/out)
daniId = -1								-- 最終的に選択した段位ID(int)
daniIdstr = ""							-- 最終的に選択した段位ID(str)

-- 選択したパネルがどの種類か
panelIdstr = ""							-- 板の種類ID(級、段、玄人以上、創作、外伝等)

-- 記録可能かどうか
IsSaveAvailable = true

optionDataIn = {}	-- 入力オプションデータ
optionDataOut = {}	-- 出力オプションデータ

-- 設定したオプションデータ
optionData_1_Speed = 0
optionData_1_Dron = 0
optionData_1_Reverse = 0
optionData_1_Randomlv = 0
optionData_1_ensoSkip = 0
optionData_1_noteDrawAdjust = 0
optionData_1_voiceSkip = 0
optionData_1_Neiro = 0

-- プレイヤーの参加情報を得る
SetPlayerJoin = function(isJoinLeft, isJoinRight)
	
	is_joinLeft = isJoinLeft
	is_joinRight = isJoinRight
	
	if (isJoinLeft) then
		is_joinPlayer[1]	= true	-- 1p側で参加
	else
		is_joinPlayer[2]	= true	-- 2p側で参加
	end
end

SetPlayerJoin(is_joinPlayer[1], is_joinPlayer[2])

-- 使うクラスを読み込む
require("dani_select.dani_select_all")

-- 初期化処理
function Init()
	-- ここで使うモジュールを初期化
	DaniSelectAllMain:Init()
end

-- 毎フレームの処理
function Proc()
	DaniSelectAllMain:Update()
end

