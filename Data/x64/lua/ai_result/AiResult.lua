-- AiResult.lua
-- AIバトルリザルト画面

-- 対応するlumenファイル
UseLumenFile = "lumen/000_default/enso_ai/result/result_ai"
--UseLumenFile = "lumen/000_default/result/result"

-- 使うクラスを読み込む
require("common.State")
require("ai_result.AiResultDebug")
require("ai_result.AiResultMain")

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
g_isBestScore_	= true		-- : ベストスコア表示をする
-- C++から値を設定
-- g_CTest_		: テスト
-- g_joinSide_	: 

-- ユーザー設定
g_isLastSong_			= false	-- 最後の曲か否か
g_isFinishAllEffect		= false	-- 全ての演出が完了したか否か
g_currentSongCount_		= 0		-- 現在の演奏曲数
g_maxSongCount_			= 0		-- 最大演奏曲数
g_isCardUser_			= false	-- カードユーザー
g_entryType_			= 0		-- エントリタイプ : 0:左側1人プレイ, 1:右側1人プレイ, 2:2人プレイ
g_isAllOnpuEnd_			= false	-- 最後まで演奏した
g_winCount_				= 0		-- 合計勝利数
g_nextReward_			= 9999	-- 次のごほうび獲得勝利数
g_winCountDisplay_		= 1		-- 合計勝利数の表示をするか否か : 0:表示しない, 1:表示する, 2:次のご褒美獲得勝利数も表示

-- 演奏結果
g_songTitle_			= ""	-- 曲名
g_result_				= 0		-- 勝敗
g_ensoResult_			= 0		-- リザルトタイプ	: 0:クリア失敗, 1:クリア成功, 2:フルコンボ, 3:ドンダフル,
g_difficulty_			= 0		-- 難易度			: 0:easy, 1:normal, 2:hard, 3:oni, 4:ura,
g_crown_				= 0		-- 王冠				: 0:なし, 1:銀, 2:金, 3:虹
g_scoreRank_			= 0		-- スコアランク		: 0:なし, 1:粋白, 2:粋銀, 3:粋金, 4:雅白, 5:雅銀, 6:雅金, 7:極虹

-- スコア
g_tamashiiGage_			= 0		-- 魂ゲージ
g_scoreNum_				= 0		-- スコア
g_goodNum_				= 0		-- 良
g_okNum_				= 0		-- 可
g_badNum_				= 0		-- 不可
g_maxcomboNum_			= 0		-- 最大コンボ数
g_dramrollNum_			= 0		-- 最大連打数
g_bestScore_			= 0		-- ベスト：スコア

-- 演奏オプション
g_optionSpeed_			= 0		-- : オプション：スピード
g_optionDron_			= false	-- : オプション：ドロン
g_optionReverse_		= false	-- : オプション：あべこべ
g_optionRandomlv_		= 0		-- : オプション：ランダム
g_optionNoteDrawAdjust_	= 0		-- : オプション：音符表示位置

g_sectionMax_			= 0		-- 区間数
g_aiDonName_			= 0		-- Aiどんちゃんの名前
g_aiDonCostume_			= 0		-- Aiどんの見た目

-- 区間成績
g_sectionResult_		= {}	-- 勝敗
g_sectionCrown_			= {}	-- 王冠
g_sectionScore_			= {}	-- スコア

g_sectionGoodNum_		= {}	-- 良
g_sectionOkNum_			= {}	-- 可
g_sectionBadNum_		= {}	-- 不可
g_sectionDramrollNum_	= {}	-- 連打数

-- 区間成績ベスト
g_sectionTotalBestScore_		= {}	-- ベスト：スコア
g_sectionBestGoodNum_			= {}	-- ベスト：良
g_sectionBestOkNum_				= {}	-- ベスト：可
g_sectionBestBadNum_			= {}	-- ベスト：不可
g_sectionBestDramrollNum_		= {}	-- ベスト：連打数

-- 総合プレイ結果で必要な情報
g_totalSectionNum_				= {}	-- 区間数[4]
g_totalSongName_				= {}	-- 曲名[4]
g_totalScoreNum_				= {}	-- スコア[4
g_totalCrown_					= {}	-- 王冠[4]
g_totalscoreRank_				= {}	-- スコアランク[4]
g_totalBestScoreNum_			= {}	-- ベスト：スコア[4]

g_totalSectionCrown_			= {}	-- 区間：王冠[4][5]
g_totalSectionTotalScore_		= {}	-- 区間：スコア[4][5]
g_totalBestSectionCrown_		= {}	-- 区間ベスト：王冠[4][5]
g_totalBestSectionTotalScore_	= {}	-- 区間ベスト：スコア[4][5]

-- ごほうび関連
g_currentNormalToken			= 0		-- 所持中の通常トークン数
g_addNormalToken				= 0		-- 獲得した通常トークン数
g_isDefaultTokenShopMessage		= false	-- ショップ購入を勧めるメッセージを出すか否か
g_isDefaultTokenComplete		= false	-- トークンをコンプリートしたか否か

g_isValidEvent					= false	-- イベントが有効か否か
g_eventTokenId					= 0		-- イベントトークンのID
g_currentEventToken				= 0		-- 所持中のイベントトークン数
g_addEventToken					= 0		-- 獲得したイベントトークン数
g_isEventTokenComplete			= false	-- トークンをコンプリートしたか否か

g_getRewardNum					= 0		-- 獲得したごほうびの数
g_rewardType					= {}	-- ごほうびタイプ（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
g_rewardUniqueId				= {}	-- ごほうびUID
g_rewardMessage					= {}	-- ごほうび獲得条件を指すワードリストのキー（"クリア達成！"とか"フルコンボ達成！"とかを指すキー）
g_rewardValue					= {}	-- 称号ならレア度、きせかえならファイルID、楽曲か音色なら未使用
g_rewardNameKey					= {}	-- ごほうびの名称を指すワードリストのキー
g_rewardTokenId					= {}	-- ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）
g_rewardTokenNeedPoint			= {}	-- 必要なトークン量。トークンIDが有効な時のみ参照してください

g_noticeRewardNum				= 0		-- 予告ごほうびの個数
g_rewardNoticeType				= {}	-- 予告ごほうびタイプ（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
g_rewardNoticeUniqueId			= {}	-- 予告ごほうびUID
g_rewardNoticeValue				= {}	-- 称号ならレア度、きせかえならファイルID、楽曲か音色なら未使用
g_rewardNoticeNameKey			= {}	-- 予告ごほうびの名称を指すワードリストのキー
g_rewardNoticeTokenId			= {}	-- ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）
g_rewardNoticeTokenNeedPoint	= {}	-- 必要なトークン量。トークンIDが有効な時のみ参照してください

-- ai用のごほうび関連
g_aiCurrentNormalToken			= {}	-- 所持中の通常トークン数
g_aiAddNormalToken				= {}	-- 獲得した通常トークン数
g_aiWinCountComplete			= {}	-- トークンをコンプリートしたか否か

g_aiGetRewardNum				= 0		-- 獲得したごほうびの数
g_aiRewardType					= {}	-- ごほうびタイプ（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
g_aiRewardUniqueId				= {}	-- ごほうびUID
g_aiRewardMessage				= {}	-- ごほうび獲得条件を指すワードリストのキー（"クリア達成！"とか"フルコンボ達成！"とかを指すキー）
g_aiRewardValue					= {}	-- 称号ならレア度、きせかえならファイルID、楽曲か音色なら未使用
g_aiRewardNameKey				= {}	-- ごほうびの名称を指すワードリストのキー
g_aiRewardTokenId				= {}	-- ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）
g_aiRewardTokenNeedPoint		= {}	-- 必要なトークン量。トークンIDが有効な時のみ参照してください

g_aiNoticeRewardNum				= 0		-- 予告ごほうびの個数
g_aiRewardNoticeType			= {}	-- 予告ごほうびタイプ（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
g_aiRewardNoticeUniqueId		= {}	-- 予告ごほうびUID
g_aiRewardNoticeValue			= {}	-- 称号ならレア度、きせかえならファイルID、楽曲か音色なら未使用
g_aiRewardNoticeNameKey			= {}	-- 予告ごほうびの名称を指すワードリストのキー
g_aiRewardNoticeTokenId			= {}	-- ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）
g_aiRewardNoticeTokenNeedPoint	= {}	-- 必要なトークン量。トークンIDが有効な時のみ参照してください

----------------------------------------
-- デバッグ用
g_DebugNum = 0				-- : デバッグ用の値

----------------------------------------
-- 初期化処理
function Init()
	Debug.PrintString("[AiResult]Init")
	if(g_DebugNum > 0)then
		AiResultDebug:SetUp()
		AiResultDebug:SetDummyData()
	end
	AiResultDebug:DebugParamPrint()
	
	AiResultDebug:RewardParam()
	AiResultDebug:RewardParam2()
	AiResultDebug:RewardParam3()
	AiResultDebug:RewardParam4()
	
	AiResultMain:Init()
end

-- 毎フレームの処理
function Proc()
	AiResultMain:Update()
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