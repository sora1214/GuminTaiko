-- AiResultDebug.lua
-- デバッグ用パラメータの設定

AiResultDebug = {
	-- ダミーデータの設定
	SetDummyData = function(this, index)

		g_isLastSong_			= false
		g_currentSongCount_		= 1
		g_maxSongCount_			= 4
		g_isCardUser_			= true					-- カードユーザーか否か
		g_isAllOnpuEnd_			= true					-- 最後まで演奏した
		g_winCount_				= 95						-- 合計勝利数
		g_nextReward_			= 1234						-- 次の勝利数
		--g_winCountDisplay_		= kWinCountNone		-- 合計勝利数を表示するか否か
		g_winCountDisplay_		= kWinCountReward		-- 合計勝利数を表示するか否か

		g_songTitle_			= "song_pklets"		-- 曲名
		--g_result_				= kWin				-- リザルトタイプ:勝利
		--g_result_				= kLose				-- リザルトタイプ:敗北
		g_ensoResult_			= 0
		g_difficulty_			= 1					-- 難易度
		g_crown_				= 1					-- 王冠
		g_scoreRank_			= 1					-- スコアランク

		-- スコア
		g_tamashiiGage_			= 50		-- 魂ゲージ
		g_scoreNum_				= 1234567	-- スコア
		g_goodNum_				= 1234		-- 良
		g_okNum_				= 1234		-- 可
		g_badNum_				= 1234		-- 不可
		g_maxcomboNum_			= 1234		-- 最大コンボ数
		g_dramrollNum_			= 1234		-- 最大連打数
		g_bestScore_			= 1000000	-- プレイ前のハイスコア

		-- 演奏オプションの設定
		g_optionSpeed_			= 1
		g_optionDron_			= true
		g_optionReverse_		= true
		g_optionRandomlv_		= 1
		g_optionNoteDrawAdjust_	= 1

		-- 区間成績の設定
		g_sectionMax_			= kAISectionNum		-- 区間数:5
		--g_sectionMax_			= kAISectionMinNum	-- 区間数:3

		for idx=1,kAISectionNum do
			--g_sectionResult_[idx]			= kWin		-- 勝敗
			g_sectionResult_[idx]			= kLose
			g_sectionCrown_[idx]			= 3

			g_sectionScore_[idx]			= 1234567	-- スコア
			g_sectionGoodNum_[idx]			= 1234		-- 良
			g_sectionOkNum_[idx]			= 1234		-- 可
			g_sectionBadNum_[idx]			= 1234		-- 不可
			g_sectionDramrollNum_[idx]		= 1234		-- 連打数

			g_sectionTotalBestScore_[idx]	= 0			-- ベスト:スコア
			g_sectionBestGoodNum_[idx]		= 0			-- ベスト:良
			g_sectionBestOkNum_[idx]		= 0			-- ベスト:可
			g_sectionBestBadNum_[idx]		= 0			-- ベスト:不可
			g_sectionBestDramrollNum_[idx]	= 0			-- ベスト:連打数

			if(idx == 3)then
				g_sectionResult_[idx]			= kLose
				g_sectionCrown_[idx]			= 0
				g_sectionTotalBestScore_[idx]	= 9999999	-- ベスト:スコア
				g_sectionBestGoodNum_[idx]		= 9999		-- ベスト:良
				g_sectionBestOkNum_[idx]		= 9999		-- ベスト:可
				g_sectionBestBadNum_[idx]		= 9999		-- ベスト:不可
				g_sectionBestDramrollNum_[idx]	= 9999		-- ベスト:連打数
			end
		end

		-- 総合プレイ結果
		this:SetTotal()

		-- ごほうび関連
		this:SetDummyReward(2)
		this:SetDummyAiReward(2)
	end,

	SetDummyReward = function(this,index)
		Debug.PrintString("[AiResultDebug]SetDummyReward")
		if(index == 1)then
			-- その1
			g_currentNormalToken			= 5				-- 所持中の通常トークン数
			g_addNormalToken				= 0				-- 獲得した通常トークン数
			g_isDefaultTokenShopMessage		= false			-- ショップ購入を勧めるメッセージを出すか否か
			g_isDefaultTokenComplete		= false			-- トークンをコンプリートしたか否か
			
			g_isValidEvent					= true			-- イベントが有効か否か
			g_eventTokenId					= 1000			-- イベントトークンのID
			g_currentEventToken				= 500			-- 所持中のイベントトークン数
			g_addEventToken					= 0				-- 獲得したイベントトークン数
			g_isEventTokenComplete			= false			-- トークンをコンプリートしたか否か
			
			g_getRewardNum					= 2												-- 獲得したごほうびの数
			g_rewardType					= {5,5}											-- ごほうびタイプ（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
			g_rewardUniqueId				= {1,32}										-- ごほうびUID
			g_rewardMessage					= {"result_reward_get", "result_reward_norma"}	-- ごほうび獲得条件を指すワードリストのキー（"クリア達成！"とか"フルコンボ達成！"とかを指すキー）
			g_rewardValue					= {1000, 32000}									-- 称号ならレア度、きせかえならファイルID、楽曲か音色なら未使用
			g_rewardNameKey					= {"costume_kigurumi_1", "costume_kigurumi_32"}	-- ごほうびの名称を指すワードリストのキー
			g_rewardTokenId					= {-1, -1}										-- ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）
			g_rewardTokenNeedPoint			= {-1, -1}										-- 必要なトークン量。トークンIDが有効な時のみ参照してください
			
			g_noticeRewardNum				= 2												-- 予告ごほうびの個数
			g_rewardNoticeType				= {3,3}											-- 予告ごほうびタイプ（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
			g_rewardNoticeUniqueId			= {15,30}										-- 予告ごほうびUID
			g_rewardNoticeValue				= {0,0}											-- 称号ならレア度、きせかえならファイルID、楽曲か音色なら未使用
			g_rewardNoticeNameKey			= {"costume_face_15", "costume_face_30"}		-- 予告ごほうびの名称を指すワードリストのキー
			g_rewardNoticeTokenId			= {1000,1000}									-- ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）
			g_rewardNoticeTokenNeedPoint	= {510, 520}									-- 必要なトークン量。トークンIDが有効な時のみ参照してください
		elseif(index == 2)then
			-- その2(どんメダルのごほうび込み)
			g_currentNormalToken			= 15				-- 所持中の通常トークン数
			g_addNormalToken				= 5					-- 獲得した通常トークン数
			g_isDefaultTokenShopMessage		= false				-- ショップ購入を勧めるメッセージを出すか否か
			g_isDefaultTokenComplete		= true				-- トークンをコンプリートしたか否か
			
			g_isValidEvent					= true				-- イベントが有効か否か
			g_eventTokenId					= 1000				-- イベントトークンのID
			g_currentEventToken				= 510				-- 所持中のイベントトークン数
			g_addEventToken					= 10				-- 獲得したイベントトークン数
			g_isEventTokenComplete			= false				-- トークンをコンプリートしたか否か
			
			g_getRewardNum					= 2												-- 獲得したごほうびの数
			g_rewardType					= {0,5,5,5,5,3}									-- ごほうびタイプ（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
			g_rewardUniqueId				= {163,31,25,26,27,15}							-- ごほうびUID
			g_rewardMessage					= {"result_reward_norma", "result_reward_get","result_reward_get","result_reward_get","result_reward_get","result_reward_get"}		-- ごほうび獲得条件を指すワードリストのキー（"クリア達成！"とか"フルコンボ達成！"とかを指すキー）
			g_rewardValue					= {0, 31000, 25000, 26000, 27000, 15000}						-- 称号ならレア度、きせかえならファイルID、楽曲か音色なら未使用
			g_rewardNameKey					= {"syougou_163", "costume_kigurumi_31", "costume_kigurumi_25", "costume_kigurumi_26", "costume_kigurumi_27", "costume_face_15"}		-- ごほうびの名称を指すワードリストのキー
			g_rewardTokenId					= {-1, 1000,1000,1000,1000,1000}				-- ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）
			g_rewardTokenNeedPoint			= {-1, 70, 230, 400, 500, 510}					-- 必要なトークン量。トークンIDが有効な時のみ参照してください
			
			g_noticeRewardNum				= 2											-- 予告ごほうびの個数
			g_rewardNoticeType				= {3,6}										-- 予告ごほうびタイプ（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
			g_rewardNoticeUniqueId			= {30,302}									-- 予告ごほうびUID
			g_rewardNoticeValue				= {0,0}										-- 称号ならレア度、きせかえならファイルID、楽曲か音色なら未使用
			g_rewardNoticeNameKey			= {"costume_face_30", "song_nanori"}		-- 予告ごほうびの名称を指すワードリストのキー
			g_rewardNoticeTokenId			= {1000,1000}								-- ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）
			g_rewardNoticeTokenNeedPoint	= {520, 530}								-- 必要なトークン量。トークンIDが有効な時のみ参照してください
		elseif(index == 3)then
			-- その3(ごほうび無し)
			g_currentNormalToken			= 0				-- 所持中の通常トークン数
			g_addNormalToken				= 0				-- 獲得した通常トークン数
			g_isDefaultTokenShopMessage		= false			-- ショップ購入を勧めるメッセージを出すか否か
			g_isDefaultTokenComplete		= false			-- トークンをコンプリートしたか否か
			
			g_isValidEvent					= false			-- イベントが有効か否か
			g_eventTokenId					= 0				-- イベントトークンのID
			g_currentEventToken				= 0				-- 所持中のイベントトークン数
			g_addEventToken					= 0				-- 獲得したイベントトークン数
			g_isEventTokenComplete			= false			-- トークンをコンプリートしたか否か
			
			g_getRewardNum					= 0												-- 獲得したごほうびの数
			g_rewardType					= {}											-- ごほうびタイプ（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
			g_rewardUniqueId				= {}											-- ごほうびUID
			g_rewardMessage					= {}											-- ごほうび獲得条件を指すワードリストのキー（"クリア達成！"とか"フルコンボ達成！"とかを指すキー）
			g_rewardValue					= {}											-- 称号ならレア度、きせかえならファイルID、楽曲か音色なら未使用
			g_rewardNameKey					= {}											-- ごほうびの名称を指すワードリストのキー
			g_rewardTokenId					= {}											-- ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）
			g_rewardTokenNeedPoint			= {}											-- 必要なトークン量。トークンIDが有効な時のみ参照してください
			
			g_noticeRewardNum				= 0												-- 予告ごほうびの個数
			g_rewardNoticeType				= {}											-- 予告ごほうびタイプ（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
			g_rewardNoticeUniqueId			= {}											-- 予告ごほうびUID
			g_rewardNoticeValue				= {}											-- 称号ならレア度、きせかえならファイルID、楽曲か音色なら未使用
			g_rewardNoticeNameKey			= {}											-- 予告ごほうびの名称を指すワードリストのキー
			g_rewardNoticeTokenId			= {}											-- ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）
			g_rewardNoticeTokenNeedPoint	= {}											-- 必要なトークン量。トークンIDが有効な時のみ参照してください
		elseif(index == 4)then
			-- その4(ごほうび1つずつ)
			g_currentNormalToken			= 10				-- 所持中の通常トークン数
			g_addNormalToken				= 5					-- 獲得した通常トークン数
			g_isDefaultTokenShopMessage		= false				-- ショップ購入を勧めるメッセージを出すか否か
			g_isDefaultTokenComplete		= false				-- トークンをコンプリートしたか否か
			
			g_isValidEvent					= true				-- イベントが有効か否か
			g_eventTokenId					= 1000				-- イベントトークンのID
			g_currentEventToken				= 510				-- 所持中のイベントトークン数
			g_addEventToken					= 10				-- 獲得したイベントトークン数
			g_isEventTokenComplete			= false				-- トークンをコンプリートしたか否か
			
			g_getRewardNum					= 2												-- 獲得したごほうびの数
			g_rewardType					= {0,3}											-- ごほうびタイプ（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
			g_rewardUniqueId				= {163,15}										-- ごほうびUID
			g_rewardMessage					= {"result_reward_norma","result_reward_get"}	-- ごほうび獲得条件を指すワードリストのキー（"クリア達成！"とか"フルコンボ達成！"とかを指すキー）
			g_rewardValue					= {0, 15000}									-- 称号ならレア度、きせかえならファイルID、楽曲か音色なら未使用
			g_rewardNameKey					= {"syougou_163", "costume_face_15"}			-- ごほうびの名称を指すワードリストのキー
			g_rewardTokenId					= {-1, 1000}									-- ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）
			g_rewardTokenNeedPoint			= {-1, 510}										-- 必要なトークン量。トークンIDが有効な時のみ参照してください
			
			g_noticeRewardNum				= 2											-- 予告ごほうびの個数
			g_rewardNoticeType				= {3,6}										-- 予告ごほうびタイプ（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
			g_rewardNoticeUniqueId			= {30,302}									-- 予告ごほうびUID
			g_rewardNoticeValue				= {0,0}										-- 称号ならレア度、きせかえならファイルID、楽曲か音色なら未使用
			g_rewardNoticeNameKey			= {"costume_face_30", "song_nanori"}		-- 予告ごほうびの名称を指すワードリストのキー
			g_rewardNoticeTokenId			= {1000,1000}								-- ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）
			g_rewardNoticeTokenNeedPoint	= {520, 530}								-- 必要なトークン量。トークンIDが有効な時のみ参照してください
		elseif(index == 5)then

		end
	end,

	SetDummyAiReward = function(this,index)
		Debug.PrintString("[AiResultDebug]SetDummyReward")
		if(index == 1)then
			-- ai用のごほうび関連
			g_aiCurrentNormalToken			= 10						-- 所持中の通常トークン数
			g_aiAddNormalToken				= 1							-- 獲得した通常トークン数
			g_aiWinCountComplete			= false
			
			g_aiGetRewardNum				= 1							-- 獲得したごほうびの数
			g_aiRewardType					= {5}						-- ごほうびタイプ（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
			g_aiRewardUniqueId				= {1}						-- ごほうびUID
			g_aiRewardMessage				= {"result_reward_get"}		-- ごほうび獲得条件を指すワードリストのキー（"クリア達成！"とか"フルコンボ達成！"とかを指すキー）
			g_aiRewardValue					= {1000}					-- 称号ならレア度、きせかえならファイルID、楽曲か音色なら未使用
			g_aiRewardNameKey				= {"costume_kigurumi_1"}	-- ごほうびの名称を指すワードリストのキー
			g_aiRewardTokenId				= {-1}						-- ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）
			g_aiRewardTokenNeedPoint		= {-1}						-- 必要なトークン量。トークンIDが有効な時のみ参照してください
			
			g_aiNoticeRewardNum				= 1							-- 予告ごほうびの個数
			g_aiRewardNoticeType			= {3}						-- 予告ごほうびタイプ（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
			g_aiRewardNoticeUniqueId		= {15}						-- 予告ごほうびUID
			g_aiRewardNoticeValue			= {0}						-- 称号ならレア度、きせかえならファイルID、楽曲か音色なら未使用
			g_aiRewardNoticeNameKey			= {"costume_face_15"}		-- 予告ごほうびの名称を指すワードリストのキー
			g_aiRewardNoticeTokenId			= {1000}					-- ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）
			g_aiRewardNoticeTokenNeedPoint	= {510}						-- 必要なトークン量。トークンIDが有効な時のみ参照してください
		elseif(index == 2)then
			-- ai用のごほうび関連
			Debug.PrintString("[AiResultDebug]SetDummyReward B")
			g_aiCurrentNormalToken			= 0							-- 所持中の通常トークン数
			g_aiAddNormalToken				= 0							-- 獲得した通常トークン数
			g_aiWinCountComplete			= false
			
			g_aiGetRewardNum				= 0							-- 獲得したごほうびの数
			g_aiRewardType					= {}						-- ごほうびタイプ（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
			g_aiRewardUniqueId				= {}						-- ごほうびUID
			g_aiRewardMessage				= {}						-- ごほうび獲得条件を指すワードリストのキー（"クリア達成！"とか"フルコンボ達成！"とかを指すキー）
			g_aiRewardValue					= {}						-- 称号ならレア度、きせかえならファイルID、楽曲か音色なら未使用
			g_aiRewardNameKey				= {}						-- ごほうびの名称を指すワードリストのキー
			g_aiRewardTokenId				= {}						-- ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）
			g_aiRewardTokenNeedPoint		= {}						-- 必要なトークン量。トークンIDが有効な時のみ参照してください
			
			g_aiNoticeRewardNum				= 1							-- 予告ごほうびの個数
			g_aiRewardNoticeType			= {3}						-- 予告ごほうびタイプ（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
			g_aiRewardNoticeUniqueId		= {15}						-- 予告ごほうびUID
			g_aiRewardNoticeValue			= {0}						-- 称号ならレア度、きせかえならファイルID、楽曲か音色なら未使用
			g_aiRewardNoticeNameKey			= {"costume_face_15"}		-- 予告ごほうびの名称を指すワードリストのキー
			g_aiRewardNoticeTokenId			= {1000}					-- ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）
			g_aiRewardNoticeTokenNeedPoint	= {100}						-- 必要なトークン量。トークンIDが有効な時のみ参照してください
		end
	end,

	SetTotal = function(this)
		-- 総合プレイ結果の設定
		Debug.PrintString("SetTotal")
		for i=1,g_maxSongCount_ do
			Debug.PrintString("ループ数 i :"..i)
			g_totalSectionNum_[i]			= 5				-- 区間数[4]
			g_totalSongName_[i]				= "song_pklets"	-- 曲名[4]
			g_totalScoreNum_[i]				= 1234567		-- スコア[4]
			g_totalCrown_[i]				= 2				-- 王冠[4]
			g_totalscoreRank_[i]			= 2				-- スコアランク[4]
			g_totalBestScoreNum_[i]			= 1000000		-- ベスト:スコア[4]

			g_totalSectionCrown_[i] = {}
			g_totalSectionTotalScore_[i] = {}
			g_totalBestSectionCrown_[i] = {}
			g_totalBestSectionTotalScore_[i] = {}

			for j=1,g_totalSectionNum_[i] do
				Debug.PrintString("ループ数 j :"..j)
				g_totalSectionCrown_[i][j]			= 2			-- 区間：王冠[4][5]
				g_totalSectionTotalScore_[i][j]		= 1234567	-- 区間：スコア[4][5]
				g_totalBestSectionCrown_[i][j]		= 2			-- 区間ベスト：王冠[4][5]
				g_totalBestSectionTotalScore_[i][j]	= 1000000	-- 区間ベスト：スコア[4][5]
			end
		end
	end,

	DebugParamPrint = function(this)
		Debug.PrintString("g_getRewardNum:"..g_getRewardNum)
		Debug.PrintString("g_noticeRewardNum:"..g_noticeRewardNum)
		
		Debug.PrintString("g_entryType_:"..g_entryType_)
		Debug.PrintString("g_sectionMax_:"..g_sectionMax_)

		-- ご褒美情報


		-- 設定によって変更する部分
		g_entryType_ = 0

		-- 勝敗の設定
		local win	= 0
		local lose	= 0
		for idx=1,g_sectionMax_ do
			if(g_sectionResult_[idx]==kWin)then
				win = win + 1
			else
				lose = lose + 1
			end
		end
		Debug.PrintString("win:"..win)
		Debug.PrintString("lose:"..lose)
		if(win > lose)then
			g_result_ = kWin
			Debug.PrintString("g_result_: set win")
		else
			g_result_ = kLose
			Debug.PrintString("g_result_: set lose")
		end
		
	end,

	RewardParam = function(this)
		Debug.PrintString("RewardParam")

		Debug.PrintString("所持中の通常トークン数："..g_currentNormalToken)
		Debug.PrintString("獲得した通常トークン数："..g_addNormalToken)
		--Debug.PrintString("ショップ購入を勧めるメッセージを出すか否か："..g_isDefaultTokenShopMessage)
		--Debug.PrintString("トークンをコンプリートしたか否か："..g_isDefaultTokenComplete)
		
		--Debug.PrintString("イベントが有効か否か："..g_isValidEvent)
		if(g_isValidEvent == true)then
			Debug.PrintString("イベント：有効")
		else
			Debug.PrintString("イベント：無効")
		end
		Debug.PrintString("イベントトークンのID："..g_eventTokenId)
		Debug.PrintString("所持中のイベントトークン数："..g_currentEventToken)
		Debug.PrintString("獲得したイベントトークン数："..g_addEventToken)
		--Debug.PrintString("トークンをコンプリートしたか否か："..g_isEventTokenComplete)
	end,

	RewardParam2 = function(this)
		for i=1,g_getRewardNum do
		--for i=1,1 do
			Debug.PrintString("ごほうびループ："..i)
			Debug.PrintString("ごほうびタイプ："..g_rewardType[i])
			Debug.PrintString("ごほうびUID："..g_rewardUniqueId[i])
			Debug.PrintString("ごほうび獲得条件を指す："..g_rewardMessage[i])
			Debug.PrintString("称号ならレア度："..g_rewardValue[i])
			Debug.PrintString("ごほうびの名称を指す："..g_rewardNameKey[i])
			Debug.PrintString("ごほうびと紐づいたトークンID："..g_rewardTokenId[i])
			Debug.PrintString("必要なトークン量。："..g_rewardTokenNeedPoint[i])
		end
	end,

	RewardParam3 = function(this)
		for j=1,g_noticeRewardNum do
			Debug.PrintString("よこくごほうびループ："..j)
			Debug.PrintString("よこくごほうびタイプ："..g_rewardNoticeType[j])
			Debug.PrintString("よこくごほうびUID："..g_rewardNoticeUniqueId[j])
			Debug.PrintString("称号ならレア度："..g_rewardNoticeValue[j])
			Debug.PrintString("よこくごほうびの名称を指す："..g_rewardNoticeNameKey[j])
			Debug.PrintString("ごほうびと紐づいたトークンID："..g_rewardNoticeTokenId[j])
			Debug.PrintString("必要なトークン："..g_rewardNoticeTokenNeedPoint[j])
		end
	end,

	RewardParam4 = function(this)
		Debug.PrintString("RewardParam4")
		local playData = PlayDataManager.GetEntryPlayData(0)
		Debug.PrintString("v11_ai_rank : "..playData.user_data.aiBattleRecordInfo.v11_ai_rank)
		Debug.PrintString("v11_win_num : "..playData.user_data.aiBattleRecordInfo.v11_win_num)
		Debug.PrintString("current_win_num : "..playData.user_data.aiBattleRecordInfo.current_win_num)
	end,

	-- デバッグ用の値を設定
	SetUp = function(this, index)
	end
}