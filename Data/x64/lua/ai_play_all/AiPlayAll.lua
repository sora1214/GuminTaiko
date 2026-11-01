-- AiPlayAll.lua
-- AIバトル総合プレイ結果画面

-- 対応するlumenファイル
UseLumenFile = "lumen/000_default/enso_ai/result/result_ai"
--UseLumenFile = "lumen/000_default/result/result"

-- 使うクラスを読み込む
require("common.State")
require("ai_play_all.AiPlayAllDebug")
require("ai_play_all.AiPlayAllMain")

----------------------------------------
-- 定数
kAISectionNum		= 5		-- 区間数
kAISectionMinNum	= 3		-- 短い区間数
kWin				= 1		-- 区間勝敗:勝利
kLose				= 2		-- 区間勝敗:敗北

kWinCountNone		= 0		-- 合計勝利数:表示しない
kWinCountDisplay	= 1		-- 合計勝利数:表示する
kWinCountReward		= 2		-- 合計勝利数:次のごほうび獲得勝利数も表示

----------------------------------------
-- グローバル変数（Lua内で使用）
g_Test_ = 0		-- テスト

-- フラグ
g_isTest_		= true		-- : true:演出を出す, false:出さない
g_isBestScore_	= false		-- : ベストスコア表示をする
-- C++から値を設定
-- g_CTest_		: テスト
-- g_joinSide_	: 

-- ユーザー設定
g_isLastSong_			= false	-- 最後の曲か否か
g_currentSongCount_		= 0		-- 現在の演奏曲数
g_maxSongCount_			= 0		-- 最大演奏曲数
g_isCardUser_			= false	-- カードユーザー
g_entryType_			= 0		-- エントリタイプ : 0:左側1人プレイ, 1:右側1人プレイ, 2:2人プレイ
g_winCount_				= 0		-- 合計勝利数
g_nextReward_			= 0		-- 次のごほうび獲得勝利数
g_winCountDisplay_		= 0		-- 合計勝利数の表示をするか否か : 0:表示しない, 1:表示する, 2:次のご褒美獲得勝利数も表示

-- 総合プレイ結果で必要な情報
g_isAllOnpuEnd_					= {}	-- 最後まで演奏した[4]
g_totalSectionNum_				= {}	-- 区間数[4]
g_totalDifficulty_				= {}	-- 難易度[4]
g_totalSongName_				= {}	-- 曲名[4]
g_totalScoreNum_				= {}	-- スコア[4
g_totalCrown_					= {}	-- 王冠[4]
g_totalscoreRank_				= {}	-- スコアランク[4]
g_totalBestScoreNum_			= {}	-- ベスト：スコア[4]
g_totalBestCrown_				= {}	-- ベスト：王冠[4]
g_totalBestScoreRank_			= {}	-- ベスト：スコアランク[4]

g_totalSectionCrown_			= {}	-- 区間：王冠[4][5]
g_totalSectionTotalScore_		= {}	-- 区間：スコア[4][5]
g_totalBestSectionCrown_		= {}	-- 区間ベスト：王冠[4][5]
g_totalBestSectionTotalScore_	= {}	-- 区間ベスト：スコア[4][5]

----------------------------------------
-- デバッグ用
g_DebugNum = 0				-- : デバッグ用の値

----------------------------------------
-- 初期化処理
function Init()
	Debug.PrintString("[AiResult]Init")
	if(g_DebugNum > 0)then
		AiPlayAllDebug:SetUp()
		AiPlayAllDebug:SetDummyData()
	end
	AiPlayAllDebug:DebugParamPrint()
	AiPlayAllMain:Init()
end

-- 毎フレームの処理
function Proc()
	AiPlayAllMain:Update()
end

-- ドン入力
function InputDon()
	if(g_joinSide_ == 1)then 
		if (Input.GetTrigger(Input.PLAYER1_OK) or Input.GetTrigger(Input.PLAYER1_CANCEL))then
			Debug.PrintString("Don 1P")
			return true
		end
	else
		if (Input.GetTrigger(Input.PLAYER2_OK) or Input.GetTrigger(Input.PLAYER2_CANCEL))then
			Debug.PrintString("Don 2P")
			return true
		end
	end

	return false
end

-- 右カツ入力
function InputKatsu_Right()
	if(g_joinSide_ == 1)then 
		if (Input.GetTrigger(Input.PLAYER1_RIGHT))then
			Debug.PrintString("Katsu_Right 1P")
			return true
		end
	else
		if (Input.GetTrigger(Input.PLAYER2_RIGHT))then
			Debug.PrintString("Katsu_Right 2P")
			return true
		end
	end

	return false
end

-- 左カツ入力
function InputKatsu_Left()
	if(g_joinSide_ == 1)then 
		if (Input.GetTrigger(Input.PLAYER1_LEFT))then
			Debug.PrintString("Katsu_Left 1P")
			return true
		end
	else
		if (Input.GetTrigger(Input.PLAYER2_LEFT))then
			Debug.PrintString("Katsu_Left 2P")
			return true
		end
	end

	return false
end