-- 対応するlumenファイル
--UseLumenFile = "lumen/result_test/result"
UseLumenFile = "lumen/000_default/result/result"

-- 使うクラスを読み込む
require("common.State")
require("result.ResultMain")

--[[
以下はｃ++から受け取ります
"g_entryType"	：　エントリタイプ（0：左側１人プレイ、1：右側１人プレイ、２：２人プレイ）
"g_songTitle"	：　曲名
"g_isLastSong"	：　プレイしたのが最後の曲か否か
"g_isGameOver"	：　ゲームオーバーフラグ（最後の曲が遊ばれた際に起動）
"g_ensoSetting"	： 難易度やオプション情報を含む演奏設定情報

"g_isTargetEvent"		: 対象イベントのリスト(イベント1～3の順でそれぞれ対象か否か)


以下は１ｐと２ｐの値が配列状に渡されます（プレイヤ数が1人の場合は要素数も１つのみ）
"g_isCardUser"	：　カードユーザか否か
"g_totalScore"	：　スコア
"g_goodNum"		：　良の数
"g_okNum"		：　可の数
"g_badNum"		：　不可の数
"g_dramrollNum"	：　最大連打数
"g_maxcomboNum"	：　最大コンボ数
"g_crown"		：　王冠（0：なし、１：銀、２：金、３：レインボー）
"g_scoreRank"	：　スコアランク（0：祭白、1：祭銀、２：祭金、３：粋白、４：粋銀、５：粋金、６：雅白、７：雅銀、８：雅金、９：極虹） ⇒　（0：なし、1：粋白、2：粋銀、3：粋金、4：雅白、5：雅銀、6：雅金、7：極虹）に変更
"g_difficulty"	：　難易度（0：かんたん、１：ふつう、２：むずかしい、３：おに、４：おにうら）

"g_optionSpeed"				：　倍速オプション（0：デフォ、１～９：1.1～1.9倍、１０：2倍、１１：2.5倍、１２：3倍、１３：3.5倍、１４：4倍）
"g_optionDron"				： どろんオプション（bool）
"g_optionReverse"			： あべこべオプション（bool）
"g_optionRandomlv"			： ランダムオプション（0：デフォ、1：きまぐれ、2：でたらめ、）
"g_optionNoteDrawAdjust"	： 音符表示位置調整オプション（-10～10の整数値）

"g_tamashiiGage"：　魂ゲージ
"g_resultType"	: リザルトタイプ（0:クリア失敗 1:クリア成功 2:フルコンボ 3:ドンダフル）
"g_hiscore"		: （プレイ前の）ハイスコア

"g_resultUniqueId"			: コラボキャラユニークID
"g_resultCharaStringId"		: コラボキャラ文字列ID
"g_resultStandCharaID"		: コラボキャラ立ち絵キャラID
"g_resultPuchiCharaID"		: コラボキャラのぷちキャラID
"g_resultStandCharaFlaFile"	: コラボキャラの立ち絵flaファイル名
"g_resultMessageRate"		: コラボキャラの台詞出現頻度[2][4]
"g_resultDispOffDonKatsu"	: コラボキャラ表示時、どんかつを非表示にするか否か（true:どんかつ非表示, false:どんかつ表示）

"g_currentNormalToken"			: 所持中の通常トークン数
"g_addNormalToken"				: 獲得した通常トークン数
"g_isDefaultTokenShopMessage"	: ショップ購入を勧めるメッセージを出すか否か
"g_isDefaultTokenComplete"		: トークンをコンプリートしたか否か

"g_isValidEvent"		: イベントが有効か否か
"g_eventTokenId"		: イベントトークンのID
"g_currentEventToken"	: 所持中のイベントトークン数
"g_addEventToken"		: 獲得したイベントトークン数
"g_isEventTokenComplete": トークンをコンプリートしたか否か

"g_getRewardNum"			: 獲得したごほうびの数
"g_rewardType1p"			: ごほうびタイプ（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
"g_rewardType2p"
"g_rewardUniqueId1p"		: ごほうびUID
"g_rewardUniqueId2p"
"g_rewardMessage1p"			: ごほうび獲得条件を指すワードリストのキー（"クリア達成！"とか"フルコンボ達成！"とかを指すキー）
"g_rewardMessage2p"
"g_rewardValue1p"			: 称号ならレア度、きせかえならファイルID、楽曲か音色なら未使用
"g_rewardValue2p"
"g_rewardNameKey1p"			: ごほうびの名称を指すワードリストのキー
"g_rewardNameKey2p"
"g_rewardTokenId1p"			: ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）
"g_rewardTokenId2p"
"g_rewardTokenNeedPoint1p"	: 必要なトークン量。トークンIDが有効な時のみ参照してください
"g_rewardTokenNeedPoint2p"

"g_noticeRewardNum"				: 予告ごほうびの個数
"g_rewardNoticeType1p"			: 予告ごほうびタイプ（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
"g_rewardNoticeType2p"
"g_rewardNoticeUniqueId1p"		: 予告ごほうびUID
"g_rewardNoticeUniqueId2p"
"g_rewardNoticeValue1p"			： 称号ならレア度、きせかえならファイルID、楽曲か音色なら未使用
"g_rewardNoticeValue2p"	
"g_rewardNoticeNameKey1p"		: 予告ごほうびの名称を指すワードリストのキー
"g_rewardNoticeNameKey2p"
"g_rewardNoticeTokenId1p"		: ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）
"g_rewardNoticeTokenId2p"
"g_rewardNoticeTokenNeedPoint1p": 必要なトークン量。トークンIDが有効な時のみ参照してください
"g_rewardNoticeTokenNeedPoint2p"
]]

g_isFadefinish = false		-- 画面切り替え後のフェードインが完了したか否か
g_isFinishAllEffect = false	-- 全ての演出が完了したか否か
g_isGameOver = false		-- ゲームオーバー演習を開始したか否か
g_isFinishGameOver = false	-- ゲームオーバー演習が完了したか否か

-- 初期化処理
function Init()
	-- ここで使うモジュールを初期化
	Main:Init()
end

-- 毎フレームの処理
function Proc()
	Main:Update()
end



