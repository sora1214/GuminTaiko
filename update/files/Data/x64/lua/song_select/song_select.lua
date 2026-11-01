-- 曲選択画面.グローバル変数Lua
-- Masayuki_Teraoka@al.bandainamco.jp

-- 対応するlumenファイル
UseLumenFile = "lumen/000_default/enso_normal/song_select/song_select_main_genre"

-- --=== 定数
kPlayerOpenNormal	        = 1					-- プレイヤーの難易度開放状況(普通)
kPlayerOpenOni		        = 2					-- プレイヤーの難易度開放状況(鬼まで)
kPlayerOpenUra		        = 3					-- プレイヤーの難易度開放状況(裏まで)

is_CardPlayer		        = {false, false}	-- カードプレイヤーかどうか
is_playerTutorial           = {false, false}	-- チュートリアルを視聴済みかどうか

-- カードプレイヤーがドンひろで設定した難易度
cardPlayerSelectedCourse    = {EnsoLevelType.kNormal, EnsoLevelType.kEasy} 

play_data_                  = {} 				-- 各ユーザーの過去プレイデータ記録(王冠・スコアランクなど)
user_setting_data_          = {}				-- そのクレジット中でのユーザーの設定データ
user_setting_Original_data_ = {}				-- ユーザーのデフォルト演奏設定

-- グローバル変数

seasonId			= 4							-- 季節ID（ショップ機能の切り替えに使用する　注意：現在は手動)
shopIdStr			= "shop"					-- ショップ用の表示ID(str)

nextMode            = SceneType.kNone			-- 遷移先

is_networkError     = false						-- 楽曲購入時にネットワーク通信エラーになったかどうか
is_freePlay		    = false						-- フリープレイかどうか

playerOpenLevel     = {}						--　プレイヤーの難易度解放状況
playerOpenOni       = {false, false}			--　各プレイヤーが難易度「おに」を開放しているか

is_touchQRCode		= false						-- QRコードをタッチしたか
QRSelectSongUniqueId = 433						-- QRコードのタッチの結果C++から引っ張ってきた楽曲のユニークID（仮でエンドリ

--　「むずかしい」までで初期化
playerOpenLevel     = {kPlayerOpenNormal, kPlayerOpenNormal}

joinSide            = {0, 0}					-- 左右どちらでプレイ([1]==1P,[2]==2P固定で0が入っていれば左、1が入っていれば右側プレイ)

is_joinLeft         = false						-- プレイヤーのログイン状況（左側）
is_joinRight        = false						-- プレイヤーのログイン状況（右側）

player_num          = 0							-- プレイ人数
entryPlayerCount    = 0							-- 参加プレイヤー数(解放ポップアップ用)

is_networkError     = false						-- ネットワークエラーかどうか

-- 決定時の各種フラグ
is_SelectTutorial   = false						-- あそびかた説明を選択したかどうか

-- 最後に選択した曲の情報(in/out)
songId              = -1						-- 最終的に選択した曲ID(int)
songIdstr           = ""						-- 最終的に選択した曲ID(str)
selectedSongData    = 0							-- 最終的に選択した曲情報が入っている変数

course              = {0, 0}					-- 難易度
selectedCourse1P    = 0							-- 最終的に1Pが選択した難易度
selectedCourse2P    = 0							-- 最終的に2Pが選択した難易度

-- 選択したパネルがどの種類か
panelIdstr          = ""						-- 板の種類ID(ジャンル、曲、戻るなど)

-- 表示するジャンルの情報
genreData           = {}						-- ジャンル情報
genreNum            = 0							-- ジャンルパネル数
genreId             = SongGenre.kPops			-- 最終的に選択したジャンル(int)
genreIdEnum         = SongGenre.kPops			-- 最終的に選択したジャンル(int)C++対応テーブル
genreIdStr          = ""						-- 最終的に選択したジャンル(str)
genreIdStrForBg     = ""						-- 最終的に選択したジャンル(str)背景用
genreSelectFlag     = false						-- ジャンルパネルを選択したか

-- 表示する曲の情報
panelNum            = 0							-- 曲パネル数
songData            = {}						-- 曲情報
songAttributeData   = {}						-- 曲の追加情報
courseId            = {0, 0}					-- 最終的に選択した難易度(int)
courseIdStr         = {}						-- 最終的に選択した難易度(str)

-- 設定したオプションデータ(左側)
optionData_1_Speed          = 0					--　音符の速度
optionData_1_Dron           = 0                 --　ドロン
optionData_1_Reverse        = 0                 --　あべこべ
optionData_1_Randomlv       = 0                 --　ランダム
optionData_1_ensoSkip       = 0                 --　演奏スキップ
optionData_1_noteDrawAdjust = 0                 --　判定位置調整
optionData_1_voiceSkip      = 0                 --　ボイススキップ
optionData_1_Neiro          = 0                 --　音色

-- 設定したオプションデータ(右側)
optionData_2_Speed          = 0                 -- 音符の速度
optionData_2_Dron           = 0                 -- ドロン
optionData_2_Reverse        = 0                 -- あべこべ
optionData_2_Randomlv       = 0                 -- ランダム
optionData_2_ensoSkip       = 0                 -- 演奏スキップ
optionData_2_noteDrawAdjust = 0                 -- 判定位置調整
optionData_2_voiceSkip      = 0                 -- ボイススキップ
optionData_2_Neiro          = 0                 -- 音色

-- ジャンルのパネルイニシャライズ(空の状態)
InitializeGenreData = function()
	Debug.PrintString("InitializeGenreData")
	genreData = {}
end

-- 曲のパネルイニシャライズ(空の状態)
InitializeSongData = function()
	Debug.PrintString("InitializeSongData")
	Debug.PrintString("InitializeSongAttributeData")

	songData          = {}
	songAttributeData = {}
end

-- プレイヤーの参加情報を得る
SetPlayerJoin = function(isJoinLeft, isJoinRight)
	
	is_joinLeft = isJoinLeft
	is_joinRight = isJoinRight
	
	if(isJoinLeft)  then player_num = player_num + 1 end
	if(isJoinRight) then player_num = player_num + 1 end
	
	if(player_num == 1) then

		if (isJoinLeft) then
			is_joinPlayer[1]	= true	-- 1p側で参加
			joinSide[1]			= 0		-- 1pの参加は左側
		else
			is_joinPlayer[2]	= true	-- 2p側で参加
			joinSide[1]			= 1		-- 1pの参加は右側
		end

	elseif (player_num == 2) then
	
		is_joinPlayer[1] = true
		is_joinPlayer[2] = true
		joinSide[1]	     = 0
		joinSide[2]	     = 1
	end
end

-- PC実行用設定
InitializeGenreData()
InitializeSongData()
SetPlayerJoin(is_joinPlayer[1], is_joinPlayer[2])

-- 使うクラスを読み込む
require("song_select.song_select_all")

-- 初期化処理
function Init()
	-- ここで使うモジュールを初期化
	SongSelectAllMain:Init()
end

-- 毎フレームの処理
function Proc()
	SongSelectAllMain:Update()
end

