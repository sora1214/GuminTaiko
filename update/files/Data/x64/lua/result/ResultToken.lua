--	スコアベース
--	2019/09/05
--	y-hara (Yasunori_Hara@al.bandainamco.jp)
--	各種スコアとか魂ゲージとかが載ったウィンドウ

require("common.Sound")
require("result.ScoreCounter")

local StateId = {
	Init_						= 0,
	WaitStart_ 					= 1,
	NormalToken_ 				= 2,
	NormalTokenInfo_			= 3,
	EventToken_ 				= 4,
	EventTokenReward_			= 5,	
	LoadNextEventTokenReward_	= 6,
	NoticeNextEventToken_ 		= 7,
	
	NormalTokenEnd_				= 98,
	EventTokenEnd_				= 99,
}

ResultToken = {}
function ResultToken.New(name)
	return
	{
		name_ = name,
		mc_,				-- このMC
		player_,			-- 1pか2pか（右側の太鼓で１人プレイの場合は1pになります。ご注意を）
		isUseRight_ = false,		-- このウィンドウが右側に表示されるか否か
		normalTokenMc_,		-- 通常トークンMC
		eventTokenMc_,		-- イベントトークンMC
		eventTokenBgMc_,	-- イベントトークン背景MC
		rewardMc_,			-- ごほうびMC
		kanstInfoMc_,		-- 通常トークンカンスト案内MC
		eventRewardNoticeMc_,	-- つぎのごほうびお知らせウィンドウMC
		
		rewardTokenIdList_,					-- ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）
		rewardTypeList_,					-- ごほうびタイプリスト（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
		rewardNameKeyList_,					-- ごほうび名を指すワードリストのキーリスト
		rewardTokenNeedPointList_,			-- ごほうびを入手するために必要なトークン数
		rewardNoticeTypeList_,				-- 予告ごほうびタイプリスト（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
		rewardNoticeNameKeyList_,			-- 予告ごほうび名を指すワードリストのキーリスト
		rewardNoticeTokenNeedPointList_,	-- 予告ごほうびを入手するために必要なトークン数
		
		isNormalTokenEnd_ = false,				-- 通常トークン処理の終了フラグ
		isEventTokenEnd_ = false,				-- イベントトークン1処理の終了フラグ
		isUpdateNormalToken_ = false,			-- 通常トークンは更新済みか否か
		isUpdateEventToken_ = false,			-- イベントトークンは更新済みか否か
		isUpdateNoticeReward_ = false,			-- ごほうび予告情報は更新済みか
		isGetEventReward_ = false,				--　イベントごほうびを獲得したか否か
		timer_ = 0,								-- 汎用タイマ
		sequence_ = 0,							-- 演出のシーケンス遷移用
		eventIndex_ = 1,
		rewardIndex_ = 1,
		event1TokenInfo_,						-- イベントトークンに関する情報

		normalTokenLabel_,

		-- 各値MCのScoreCounterをNewする
		currentNormalToken_ = ScoreCounter.New("currentNormalToken"),
		addNormalToken_ 	= ScoreCounter.New("addNormalToken"),		
		currentEventToken_ 	= ScoreCounter.New("currentEventToken"),
		addEventToken_ 		= ScoreCounter.New("addEventToken"),
		
		Init = function(this, mc, playerIndex, rewardBase, eventTokenBg)
			Debug.PrintString("!!!ResultToken Initialize!!!@"..this.name_)
			Lumen.Play()
			this.mc_ = mc
			this.player_ = playerIndex
			this.rewardMc_ = rewardBase
			this.eventTokenBgMc_ = eventTokenBg
			this.normalTokenMc_ = mc:GetChildMc("normal_token_mc",true)
			this.eventTokenMc_ = mc:GetChildMc("event_token_mc",true)
			this.kanstInfoMc_ = mc:GetChildMc("kanst_info",true)
			this.eventRewardNoticeMc_ = mc:GetChildMc("event_reward_notice",true)
			
			if(playerIndex == 1 and (g_entryType == 0 or g_entryType == 2)) then
				this.isUseRight_ = false
			else
				this.isUseRight_ = true
			end
			
			this.currentNormalToken_:Init(this.normalTokenMc_.current_token_num, 3, g_currentNormalToken[this.player_] - g_addNormalToken[this.player_])
			this.addNormalToken_:Init(this.normalTokenMc_.add_token_num, 2, g_addNormalToken[this.player_])
			
			-- ↓春夏秋冬は後で自動化予定
			--  春(116, 0, 39) 夏(0, 40, 134) 秋(125, 30 ,0) 冬(50, 50, 95)
			--this.normalTokenMc_.text_event_name:SetColorTransform(256,256,256,256,216,0,100,0)
			--this.normalTokenMc_.text_event_name:SetColorTransform(256,256,256,256,125,30,0,0)
			this.normalTokenMc_.text_event_name:SetColorTransform(256,256,256,256,50,50,95,0)

			this.normalTokenMc_.text_event_name:SetText("text_eventname1","result_token_name")
			this.normalTokenMc_.text_token_info:SetText("text_info","result_token_info")
			
			-- カードユーザなら実行
			if(g_isCardUser[this.player_] == true) then
				this.currentNormalToken_:SkipCounter()
				-- 獲得した通常トークンが10未満なら数字をセンタリング
				if(g_addNormalToken[this.player_] < 10)then
					this.normalTokenMc_.add_token_num:GotoAndStop("digit_1")
				end
				this.addNormalToken_:SkipCounter()
			
				-- イベントトークンに関する情報を取得（将来的にはここからイベント３つ分の情報を取得する）
--				this.event1TokenInfo_ = PlayDataManager.GetUserEventTokenInfo(this.player_ - 1, 1)
			
				-- イベントの有効フラグを調べ、有効なイベントがあれば初期化
--				if(this:IsSearchTargetEvent() == true) then	--ローンチ時封印

				-- ↓後で状況に合わせて自動で変えれるようにする
				this.normalTokenLabel_ = "winter"
				-- Debug.PrintString(this.normalTokenLabel_)
				this.normalTokenMc_.token_mc:GotoAndStop(this.normalTokenLabel_)
				this.normalTokenMc_.token_comp_mc:GotoAndStop(this.normalTokenLabel_)
				this.normalTokenMc_.normal_token_medal_anime.token_don_icons:GotoAndStop(this.normalTokenLabel_)
				this.normalTokenMc_.normal_token_medal_anime.token_falling_icons:GotoAndStop(this.normalTokenLabel_)

				
				if(g_isValidEvent[this.player_] == true) then
					this.currentEventToken_:Init(this.eventTokenMc_.current_token_num, 3, g_currentEventToken[this.player_] - g_addEventToken[this.player_])
					-- 獲得したイベントトークンが10未満なら数字をセンタリング
					if(g_addEventToken[this.player_] < 10) then
						this.eventTokenMc_.add_token_num:GotoAndStop("digit_1")
					end
					this.currentEventToken_:SkipCounter()
					this.addEventToken_:Init(this.eventTokenMc_.add_token_num, 2, g_addEventToken[this.player_])
					this.addEventToken_:SkipCounter()
					
					-- 予告ごほうびの表示に必要な情報を取得
					if(this.player_ == 1) then
						this.rewardTokenIdList_ = g_rewardTokenId1p
						this.rewardTypeList_ = g_rewardType1p
						this.rewardNameKeyList_ = g_rewardNameKey1p
						this.rewardTokenNeedPointList_ = g_rewardTokenNeedPoint1p
						this.rewardNoticeTypeList_ = g_rewardNoticeType1p
						this.rewardNoticeNameKeyList_ = g_rewardNoticeNameKey1p
						this.rewardNoticeTokenNeedPointList_ = g_rewardNoticeTokenNeedPoint1p
					else
						this.rewardTokenIdList_ = g_rewardTokenId2p
						this.rewardTypeList_ = g_rewardType2p
						this.rewardNameKeyList_ = g_rewardNameKey2p
						this.rewardTokenNeedPointList_ = g_rewardTokenNeedPoint2p
						this.rewardNoticeTypeList_ = g_rewardNoticeType2p
						this.rewardNoticeNameKeyList_ = g_rewardNoticeNameKey2p
						this.rewardNoticeTokenNeedPointList_ = g_rewardNoticeTokenNeedPoint2p
					end
								
					this:InitNoticeReward()-- 予告ごほうびの初期化
				end
			end
		end,
		
		


		-- 予告ごほうびの初期化
		InitNoticeReward = function(this)
			-- イベントトークンでごほうびを獲得しているか否かを確認
			for idx = 1, g_getRewardNum[this.player_] do
				if(this.rewardTokenIdList_[idx] >= 1000) then
					this.isGetEventReward_ = true
					this.rewardIndex_ = idx
				end
			end

			if(this.isGetEventReward_ == true) then
				this:UpdateNoticeReward(false)
			else
				this:UpdateNoticeReward(true)
			end
		end,

		

		--	毎フレーム実行
		Update = function(this)
			this.currentNormalToken_:Update()
			this.timer_ = this.timer_ + 1			
			
			
			-- メインシーケンス
			if(this.sequence_ == StateId.WaitStart_) then
				if(this.timer_ > 150) then
					this.timer_ = 0
					this.sequence_ = StateId.NormalToken_
				end

				
			elseif(this.sequence_ == StateId.NormalToken_) then
				-- 通常トークンが増加していたら表示内容を更新
				if(this.isUpdateNormalToken_ == false) then
					this.normalTokenMc_:GotoAndPlay("update")
					this.normalTokenMc_.normal_token_medal_anime:GotoAndPlay("start")
					-- サウンド（トークンのカウントアップ、メダルがはじける、ウィンドウが拡縮）
					if(this.isUseRight_ == false) then
						TSound:Play("se_common_v12a","token_up_l")							
						TSound:Play("se_common_v12a","token_fixed_l")
					else
						TSound:Play("se_common_v12a","token_up_r")							
						TSound:Play("se_common_v12a","token_fixed_r")
					end
					this.isUpdateNormalToken_ = true
				end
				
				-- タイミングを見計らって現在の所持トークン量を更新する
				if(this.mc_:IsInCurrentLabelMc("normal_token_mc","update_token") == true) then
					this.currentNormalToken_:DirectCounter(g_currentNormalToken[this.player_])
				end
				
				if(this.timer_ > 500) then
					this.timer_ = 0
					-- 通常トークンがカンストなら案内を表示
					if(g_isDefaultTokenComplete[this.player_] == true) then
						this.sequence_ = StateId.NormalTokenInfo_
						this.kanstInfoMc_:GotoAndPlay("start")
						this.kanstInfoMc_.achieve_caption:GotoAndStop("result_reward_token_kanst")
						this.kanstInfoMc_.text_token_info:SetText("text_info","result_token_kanst")
						this.kanstInfoMc_.achieve_caption.text_reward_midasi01.text_title1:SetText("text_1","result_token_kanst_caption")
						this.kanstInfoMc_.achieve_caption.text_reward_midasi01.text_title2:SetText("text_2","result_token_kanst_caption")
						-- サウンド
						if(this.isUseRight_ == false) then
							TSound:Play("se_common_v12a","gohoubi_get_l")
--							TSound:Play("se_common_v12a","popup_l")
							TSound:Play("se_result_v12a","reward_ribbon_l")
						else
							TSound:Play("se_common_v12a","gohoubi_get_r")
--							TSound:Play("se_common_v12a","popup_r")
							TSound:Play("se_result_v12a","reward_ribbon_r")					
						end
					-- いずれにも当てはまらなければ通常トークン演出は終了
					else
						this.sequence_ = StateId.NormalTokenEnd_
					end
				end
			
				
			elseif(this.sequence_ == StateId.NormalTokenInfo_) then
				if(this.timer_ > 1200) then
					this.sequence_ = StateId.NormalTokenEnd_
					this.kanstInfoMc_:GotoAndPlay("end")
				end


			elseif(this.sequence_ == StateId.EventToken_) then
				if(this.timer_ > 200 and this.isUpdateEventToken_ == false) then
					-- 加算演出を開始	
					this.eventTokenMc_:GotoAndPlay("update")
					this.eventTokenBgMc_:StartUpdateEventToken()
					-- サウンド（トークンのカウントアップ、メダルがはじける、ウィンドウが拡縮）
					if(this.isUseRight_ == false) then
						TSound:Play("se_common_v12a","token_up_l")							
						TSound:Play("se_common_v12a","token_fixed_l")
					else
						TSound:Play("se_common_v12a","token_up_r")							
						TSound:Play("se_common_v12a","token_fixed_r")
					end
						
					this.normalTokenMc_:SetVisible(false)	-- ついでに通常トークンはいらないので消しておく
					this.isUpdateEventToken_ = true
				end
				
				-- タイミングを見計らって現在の所持トークン量を更新する
				if(this.mc_:IsInCurrentLabelMc("event_token_mc","update_token") == true) then
					this.currentEventToken_:DirectCounter(g_currentEventToken[this.player_])				
				end
				
				if(this.timer_ > 1200) then
					this.timer_ = 0
					--[[ !!!!!!ローンチ時は封印!!!!!!
					-- 他にも対象となっているイベントがあるか探し、あればそちらを表示する
					this.eventIndex_ = this.eventIndex_ + 1
					if(this:IsSearchTargetEvent() == true) then
						this.sequence_ = StateId.NoticeNextEventToken_
					--　なければ終了
					else
						this.sequence_ = StateId.EventTokenReward_
					end
					]]--						
						
					-- イベントごほうびを獲得しているか否かで分岐
					-- 獲得している場合はごほうび獲得パネルを表示
					if(this.isGetEventReward_ == true) then
						this.eventTokenMc_:GotoAndPlay("end")
						this.eventTokenBgMc_:EndDisplayEventToken()
						this.rewardMc_:UpdateRewardPanel(g_eventTokenId[this.player_], true)
						this.sequence_ = StateId.EventTokenReward_
					-- 獲得していない場合は終了
					else
						this.sequence_ = StateId.EventTokenEnd_
					end
				end


				
			elseif(this.sequence_ == StateId.EventTokenReward_) then
				-- ごほうびパネルが終了したか否かを常に問い合わせ、完了し次第次のシーケンスへ遷移
				isRewardPanelEnd = false
				if(this.rewardMc_:GetIsRewardPanelEnd() == true) then
					isRewardPanelEnd = true
				end
		
				if(isRewardPanelEnd == true) then
					this.timer_ = 0
					this.eventRewardNoticeMc_.reward_panel_bg:GotoAndStop("next_reward")
					this.sequence_ = StateId.LoadNextEventTokenReward_
				end
				
					
			elseif(this.sequence_ == StateId.LoadNextEventTokenReward_) then			
				if(this.timer_ > 100 and this.isUpdateNoticeReward_ == false) then
					if(g_isEventTokenComplete[this.player_] == true) then
						-- イベントトークンがカンストの場合はカンストインフォを表示
						this.kanstInfoMc_:GotoAndPlay("start")
						this.kanstInfoMc_.achieve_caption:GotoAndStop("event_token_kanst")
						this.kanstInfoMc_.text_token_info:SetText("text_info","result_event_token_kanst")
						this.kanstInfoMc_.achieve_caption.text_reward_midasi01.text_title1:SetText("text_1","result_event_token_kanst_caption")
						this.kanstInfoMc_.achieve_caption.text_reward_midasi01.text_title2:SetText("text_2","result_event_token_kanst_caption")
						-- サウンド
						if(this.isUseRight_ == false) then
							TSound:Play("se_common_v12a","gohoubi_get_l")
							TSound:Play("se_result_v12a","reward_ribbon_l")
						else
							TSound:Play("se_common_v12a","gohoubi_get_r")
							TSound:Play("se_result_v12a","reward_ribbon_r")				
						end
					else
						-- そうでない場合は次に貰えるごほうびお知らせウィンドウを表示
						this.eventRewardNoticeMc_:GotoAndPlay("start")
						this.eventRewardNoticeMc_.text_next_reward:SetText("text_token_event_02","result_reward_next")
						-- サウンド（ポップアップ）
						if(this.isUseRight_ == false) then
							TSound:Play("se_common_v12a","popup_l")
						else
							TSound:Play("se_common_v12a","popup_r")
						end
					end
					this.isUpdateNoticeReward_ = true
				end
			
				if(this.timer_ > 800) then
					this.timer_ = 0
					-- 既に表示されているものは消す
					if(g_isEventTokenComplete[this.player_] == true) then
						this.kanstInfoMc_:GotoAndPlay("end")			
--						this.eventTokenMc_.reward_notice:SetVisible(false)	-- カンストの場合は次のごほうび表示もついでに消しとく
--						this.eventTokenMc_.text_target_token:SetVisible(false)	-- 目標トークン数もついでに消しとく
						-- カンストの場合はイベントトークンをカンスト表記に切り替える
						this.eventTokenMc_:GotoAndStop("comp")
						this.eventTokenMc_.text_token_comp:SetText("text","token_complete")
						this.eventTokenBgMc_:ChangeKanstEventToken()						
					else
						this.eventRewardNoticeMc_:GotoAndPlay("end")
						this.eventTokenMc_:GotoAndPlay("stop")
					end
					-- 内容を更新して、イベントトークンウィンドウを再表示する
					this:UpdateNoticeReward(true)
					this.mc_:GotoAndPlay("change_event")
					this.eventTokenBgMc_:StartDisplayEventToken()
					this.eventTokenMc_.add_token_num:SetVisible(false)
					this.eventTokenMc_.add_token_bg:SetVisible(false)
					this.sequence_ = StateId.NoticeNextEventToken_
				end
				
				
				
			elseif(this.sequence_ == StateId.NoticeNextEventToken_) then
				this.sequence_ = StateId.EventTokenEnd_
			
			
				
				
				
				
			--[[ !!!!!!ローンチ時は封印!!!!!!
			elseif(this.sequence_ == StateId.NoticeNextEventToken_) then
				if(this.timer_ > 100) then
					this.timer_ = 0
					this.isUpdateEventToken_ = false
					-- イベントトークンを再表示
					this.eventTokenMc_:GotoAndPlay("start")
					this.currentEventToken_:DirectCounter(this.currentEventTokenNum_[this.eventIndex_] - this.addEventTokenNum_[this.eventIndex_])
					this.addEventToken_:DirectCounter(this.addEventTokenNum_[this.eventIndex_])
					this.sequence_ = StateId.EventToken_
				end
			]]--
			
			
		
		
			elseif(this.sequence_ == StateId.NormalTokenEnd_) then
				this.isNormalTokenEnd_ = true
			elseif(this.sequence_ == StateId.EventTokenEnd_) then
				this.isEventTokenEnd_ = true
			end
		end,
		--	ここまでUpdate
		
		
		
		
		
		-- 通常トークン演出終了フラグのゲット関数
		GetIsNormalTokenEnd = function(this)
			return this.isNormalTokenEnd_
		end,
		
		
		-- イベントトークン演出終了フラグのゲット関数
		GetIsEventTokenEnd = function(this)
			return this.isEventTokenEnd_
		end,
		
		
		
		
		-- 通常トークン情報の更新開始指示
		StartUpdateNormalToken = function(this)
			-- 通常トークンが増加しているか否かで分岐
			if(g_addNormalToken[this.player_] > 0 ) then
				-- 通常トークンが増加していたら、通常トークンパネルをポップアップ
				this.timer_ = 0
				this.mc_:GotoAndPlay("start")
				this.sequence_ = StateId.WaitStart_
				-- サウンド（通常トークンパネルのポップアップ）
				if(this.isUseRight_ == false) then
					TSound:Play("se_common_v12a","popup_l")
				else
					TSound:Play("se_common_v12a","popup_r")
				end
			else
				-- 通常トークンが増加していなければ即終了
				this.sequence_ = StateId.NormalTokenEnd_
				-- 通常トークンがカンストしている場合は通常トークンを非表示(じゃないとイベントトークン表示時に若干見切れる)
				if(g_isDefaultTokenComplete[this.player_] == true) then
					this.normalTokenMc_:SetVisible(false)
				end
			end
		end,
		
	
	
		-- イベントトークン情報の更新開始指示
		StartUpdateEventToken = function(this)
			-- イベントが開催中で、かつイベントトークンが増加していたら実行
			if(g_isValidEvent[this.player_] == true and g_addEventToken[this.player_] > 0 ) then
				-- 開催中かつイベントトークンが増加していたら、イベントトークンパネルをポップアップ
				this.timer_ = 0
				this.mc_:GotoAndPlay("change_event")
				this.eventTokenBgMc_:StartDisplayEventToken()				
				this.sequence_ = StateId.EventToken_
				-- 通常トークンが増加していない場合、通常トークンは最初から非表示
				if(g_addNormalToken[this.player_] < 1 ) then
					this.normalTokenMc_:SetVisible(false)
				end
				-- サウンド（イベントトークンパネルのポップアップ）
				if(this.isUseRight_ == false) then
					TSound:Play("se_common_v12a","popup_l")
				else
					TSound:Play("se_common_v12a","popup_r")
				end
			-- トークンは増加していないが、イベントの開催中かつ何らかのイベントごほうびをゲットしていたら実行
			elseif(g_isValidEvent[this.player_] == true and this.isGetEventReward_ == true) then
				-- この時点で通常トークンが表示されている場合があるので、もし表示されていたら非表示にする
				if(g_addNormalToken[this.player_] > 0 ) then
					this.mc_:GotoAndPlay("change_event")
				end
				-- イベントトークンの加算演出を飛ばし、いきなりごほうび獲得演出を動かす
				this.eventTokenMc_:SetVisible(false)
				this.rewardMc_:UpdateRewardPanel(g_eventTokenId[this.player_], true)
				this.sequence_ = StateId.EventTokenReward_
			else
				-- 上記に当てはまらなければ即終了
				this.sequence_ = StateId.EventTokenEnd_
			end
		end,
		

		
		-- 予告ごほうび情報の更新
		-- isUseRewardNoticeList : RewardNoticeListの内容で更新するか否か。falseの場合は RewardList　（つまりこれから獲得処理を行うごほうび）の情報で更新
		UpdateNoticeReward = function(this, isUseRewardNoticeList)
			-- RewardNoticeList の中に入っている予告情報で初期化
			if(isUseRewardNoticeList == true)then		
				if(g_noticeRewardNum[this.player_] >= 1) then	-- ｃ++から受け取った予告ごほうび情報の個数が0以下だったらやらない ※将来的にはthis.rewardIndex_を元に、予告ごほうび情報が存在するか否かをキチンと確認してください
					-- ごほうびの種類の初期化
					if(this.rewardNoticeTypeList_[1] == 0) then		-- 称号の場合
						this.eventTokenMc_.reward_notice:GotoAndStop("shogo")
						this.eventTokenMc_.reward_notice:SetText("text_jnl","result_reward_title")
					elseif(this.rewardNoticeTypeList_[1] >= 1 and this.rewardNoticeTypeList_[1] <= 5) then	-- きせかえの場合
						this.eventTokenMc_.reward_notice:GotoAndStop("cos")
						this.eventTokenMc_.reward_notice:SetText("text_jnl","result_reward_costume_"..this.rewardNoticeTypeList_[1])
					elseif(this.rewardNoticeTypeList_[1] == 6) then	-- 楽曲の場合
						this.eventTokenMc_.reward_notice:GotoAndStop("song")
						this.eventTokenMc_.reward_notice:SetText("text_jnl","result_reward_song")
					elseif(this.rewardNoticeTypeList_[1] == 7) then	-- 音色の場合
						this.eventTokenMc_.reward_notice:GotoAndStop("tone")
						this.eventTokenMc_.reward_notice:SetText("text_jnl","result_reward_instrumental")			
					end			
					-- ごほうび名の初期化
					this.eventTokenMc_.reward_notice.text_token_reward:SetText("text_title",this.rewardNoticeNameKeyList_[1])
					-- 目標トークン数の初期化
					Debug.PrintString("!!!target_token!!! : ".."result_event_target_"..this.rewardNoticeTokenNeedPointList_[1])
					this.eventTokenMc_.text_target_token:SetText("text_info","result_event_target_"..this.rewardNoticeTokenNeedPointList_[1])
				end
			-- RewardList（つまりこれから獲得処理を行うごほうび）で予告情報を初期化
			else
				-- ごほうびの種類の初期化
				if(this.rewardTypeList_[this.rewardIndex_] == 0) then		-- 称号の場合
					this.eventTokenMc_.reward_notice:GotoAndStop("shogo")
					this.eventTokenMc_.reward_notice:SetText("text_jnl","result_reward_title")
				elseif(this.rewardTypeList_[this.rewardIndex_] >= 1 and this.rewardTypeList_[this.rewardIndex_] <= 5) then	-- きせかえの場合
					this.eventTokenMc_.reward_notice:GotoAndStop("cos")
					this.eventTokenMc_.reward_notice:SetText("text_jnl","result_reward_costume_"..this.rewardTypeList_[this.rewardIndex_])
				elseif(this.rewardTypeList_[this.rewardIndex_] == 6) then	-- 楽曲の場合
					this.eventTokenMc_.reward_notice:GotoAndStop("song")
					this.eventTokenMc_.reward_notice:SetText("text_jnl","result_reward_song")
				elseif(this.rewardTypeList_[this.rewardIndex_] == 7) then	-- 音色の場合
					this.eventTokenMc_.reward_notice:GotoAndStop("tone")
					this.eventTokenMc_.reward_notice:SetText("text_jnl","result_reward_instrumental")			
				end
				-- ごほうび名の初期化
				this.eventTokenMc_.reward_notice.text_token_reward:SetText("text_title",this.rewardNameKeyList_[this.rewardIndex_])
				-- 目標トークン数の初期化
				Debug.PrintString("!!!target_token!!! : ".."result_event_target_"..this.rewardTokenNeedPointList_[this.rewardIndex_])
				this.eventTokenMc_.text_target_token:SetText("text_info","result_event_target_"..this.rewardTokenNeedPointList_[this.rewardIndex_])

				--ついでに、次のごほうび予告ウィンドウも初期化
				if(g_noticeRewardNum[this.player_] >= 1) then	-- ｃ++から受け取った予告ごほうび情報の個数が0以下だったらやらない ※将来的にはthis.rewardIndex_を元に、予告ごほうび情報が存在するか否かをキチンと確認してください
					if(this.rewardNoticeTypeList_[1] == 0) then		-- 称号の場合
						this.eventRewardNoticeMc_.reward_panel_jnl:GotoAndStop("shogo")
						this.eventRewardNoticeMc_.reward_panel_jnl:SetText("text_jnl","result_reward_title")
					elseif(this.rewardNoticeTypeList_[1] >= 1 and this.rewardNoticeTypeList_[1] <= 5) then	-- きせかえの場合
						this.eventRewardNoticeMc_.reward_panel_jnl:GotoAndStop("cos")
						this.eventRewardNoticeMc_.reward_panel_jnl:SetText("text_jnl","result_reward_costume_"..this.rewardNoticeTypeList_[1])
					elseif(this.rewardNoticeTypeList_[1] == 6) then	-- 楽曲の場合
						this.eventRewardNoticeMc_.reward_panel_jnl:GotoAndStop("song")
						this.eventRewardNoticeMc_.reward_panel_jnl:SetText("text_jnl","result_reward_song")
					elseif(this.rewardNoticeTypeList_[1] == 7) then	-- 音色の場合
						this.eventRewardNoticeMc_.reward_panel_jnl:GotoAndStop("tone")
						this.eventRewardNoticeMc_.reward_panel_jnl:SetText("text_jnl","result_reward_instrumental")			
					end			
					-- ごほうび名の初期化
					this.eventRewardNoticeMc_.reward_panel_jnl.text_reward:SetText("text_title",this.rewardNoticeNameKeyList_[1])
				end
			end
		end,
		
		
		
		
		
		
		
		--[[！！！夢の跡地　複数イベントの同時開催が決まったら改造してください！！！
		-- 有効になっているイベントを探す
		IsSearchTargetEvent = function(this)
			for idx = this.eventIndex_, 3 do
				if(g_isTargetEvent[idx] == true) then
					this.eventIndex_ = idx
					break
				end
			end
			
			-- 有効なイベントが見つかっていたらtrueを、そうでなければfalseを返す
			if(this.eventIndex_ <= 3 and g_isTargetEvent[this.eventIndex_] == true) then
				return true
			else
				return false
			end
		end,
		--]]
	}
end