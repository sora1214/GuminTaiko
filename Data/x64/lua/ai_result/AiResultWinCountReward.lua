-- AiResultWinCountReward.lua
-- AIバトルリザルト画面:ごほうびウィンドウ
AiResultWinCountReward = {}

local StateId = {
	Init_				= 0,
	RewardPanel_ 		= 1,
	JudgeNextScene_		= 2,
	RewardChoicePanel_	= 3,
	ChangePlayerInfo_	= 4,
	LoadNextReward_		= 5,
	End_				= 99,
}

function AiResultWinCountReward.New(name)
	return
	{	
		name_ = name,
		mc_,						-- result_reward.flaのmain
		mcR_,						-- 右側MC
		mcL_,						-- 左側MC
		mcTokenBaseR_,				-- token_base_R
		mcTokenBaseL_,				-- token_base_L
		rewardPanelMc_,				-- ごほうびパネルMC
		rewardChoicePanelMc_,		-- ごほうび選択MC
		namePlate_,					-- ネームプレートMC
			--eventTokenBgMc_,			-- イベントごほうび背景MC
		controlGuideRMc_,			-- 操作ガイドMC
		controlGuideLMc_,			-- 操作ガイドMC
		eventTokenMc_,				-- イベントトークンMC
		eventRewardNoticeMc_,		-- つぎのごほうびお知らせウィンドウMC
		nextRewardNum_,				-- 次の勝利数カウンター
		sectionMain_,				-- 区間メイン

		player_ = 1,				-- 1pか2pか（右側の太鼓で１人プレイの場合は1pになります。ご注意を）
		isUseRight_ = false,		-- このウィンドウが右側に表示されるか否か
		timer_ = 0,					-- 汎用タイマ
		sequence_ = 0,				-- シーケンス遷移用
		rewardIndex_ = 1,
		targetRewardTokenId_ = 0,	-- 対象とするトークンID（このIDに紐づいたごほうびのみを表示する）
		rewardTypeList_,			-- ごほうびタイプリスト（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
		rewardUniqueIdList_,		-- ごほうびUIDリスト
		rewardMessageList_,			-- ごほうび獲得条件を指すワードリストのキーリスト（"クリア達成！"とか"フルコンボ達成！"とかを指すキー）
		rewardValueList_,			-- 称号ならレア度、きせかえならファイルID、楽曲か音色なら未使用
		rewardNameKeyList_,			-- ごほうび名を指すワードリストのキーリスト
		rewardTokenIdList_,			-- ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）

		rewardNoticeTypeList_,				-- 予告ごほうびタイプリスト（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
		rewardNoticeNameKeyList_,			-- 予告ごほうび名を指すワードリストのキーリスト
		rewardNoticeTokenNeedPointList_,	-- 予告ごほうびを入手するために必要なトークン数

		currentCursorPosition_,		-- 現在のカーソル位置
		nextCursorPosition_,		-- 次のカーソル位置
		currentCostume_,			-- 現在のきせかえ情報
		oldTitle_ = "",				-- 変更前の称号文字列
		oldTitleBaseId_ = 0,		-- 変更前の称号板ID
		isDonSmoke_ = false,		-- マイドンの上に雲が発生しているか否か
		isDecide_ = false,			-- 決定ボタンが押されたか否か
		isEnableMoveCursor_ = false,-- カーソル移動を受け付けているか否か
		isRewardPanelEnd_ = false,	-- ごほうびパネルの全処理が完了したか否か
		isUpdateNoticeReward_ = false,			-- ごほうび予告情報は更新済みか

		Init = function(this, mc, eventMc, playerIndex, namePlate, winCounter, sectionMain)
			Debug.PrintString("!!!ResultReward Initialize!!!@"..this.name_)
			-- Lumen.Play()
			this.mc_ = mc
			this.mcR_ = this.mc_.reward_base_R
			this.mcL_ = this.mc_.reward_base_L
			this.mcTokenBaseR_ = this.mc_.token_base_R
			this.mcTokenBaseL_ = this.mc_.token_base_L

			--this.rewardPanelMc_ = this.mcR_:GetChildMc("reward_panel_ai",true)
			this.rewardPanelMc_ = this.mcL_:GetChildMc("reward_panel_ai",true)
			this.rewardPanelMc_.choice_button.btn_text_3:SetText("text_btn","result_next")
			this.rewardChoicePanelMc_ = this.mcL_:GetChildMc("reward_choice_panel",true)
			this.rewardChoicePanelMc_.reward_choice_button.btn_text_1:SetText("text_btn","result_yes")
			this.rewardChoicePanelMc_.reward_choice_button.btn_text_2:SetText("text_btn","result_no")
			this.player_ = playerIndex
			this.namePlate_ = namePlate
				--this.eventTokenBgMc_ = eventTokenBg
			-- 予告ごほうび用
			--this.eventTokenMc_			= this.mcTokenBaseR_:GetChildMc("event_token_mc",true)
			--this.eventRewardNoticeMc_	= this.mcTokenBaseR_:GetChildMc("event_reward_notice",true)
			this.eventTokenMc_			= this.mcTokenBaseL_:GetChildMc("event_token_mc",true)
			this.eventRewardNoticeMc_	= this.mcTokenBaseL_:GetChildMc("event_reward_notice",true)

			this.nextRewardNum_ = winCounter
			this.sectionMain_ = sectionMain

			if(playerIndex == 1 and (g_entryType_ == 0 or g_entryType_ == 2)) then
				this.isUseRight_ = false
			else
				this.isUseRight_ = true
			end

			-- 現在のきせかえ情報を取得
			if(g_joinSide_ == 1) then
				this.currentCostume_ = PlayDataManager.GetUserClothes(0)
			else
				this.currentCostume_ = PlayDataManager.GetUserClothes(1)
			end
			
			this.rewardTypeList_ = g_aiRewardType
			this.rewardUniqueIdList_ = g_aiRewardUniqueId
			this.rewardMessageList_ = g_aiRewardMessage
			this.rewardValueList_ = g_aiRewardValue
			this.rewardNameKeyList_ = g_aiRewardNameKey
			this.rewardTokenIdList_ = g_aiRewardTokenId

			-- 予告ごほうびの表示に必要な情報を取得
			this.rewardNoticeTypeList_				= g_aiRewardNoticeType
			this.rewardNoticeNameKeyList_			= g_aiRewardNoticeNameKey
			this.rewardNoticeTokenNeedPointList_	= g_aiRewardNoticeTokenNeedPoint

			this:UpdateNoticeReward(true)
			-- this:InitNoticeReward()		-- 予告ごほうびの初期化
		end,
		
		-- 操作ガイドの初期化
		InitControlGuide = function(this, GuideRMc, GuideLMc)
			this.controlGuideRMc_ = GuideRMc:GetChildMc("main",true)
			this.controlGuideRMc_.guide_taiko_mc.select_instance.text_guide_instance:SetText("text_guide","select")
			this.controlGuideRMc_.guide_taiko_mc.decide_instance.text_guide_instance:SetText("text_guide","decide")

			this.controlGuideLMc_ = GuideLMc:GetChildMc("main",true)
			this.controlGuideLMc_.guide_taiko_mc.select_instance.text_guide_instance:SetText("text_guide","select")
			this.controlGuideLMc_.guide_taiko_mc.decide_instance.text_guide_instance:SetText("text_guide","decide")
		end,
		
		Update = function(this)
			this.timer_ = this.timer_ + 1
			
			-- キー入力処理(左右の太鼓を判別してカーソル移動)
			if(this.sequence_ == StateId.RewardChoicePanel_ and this.isEnableMoveCursor_ == true) then
				if(g_joinSide_ == 1) then
					if (Input.GetTrigger(Input.PLAYER1_RIGHT) == true) then
						this.nextCursorPosition_ = this.nextCursorPosition_ + 1
					elseif (Input.GetTrigger(Input.PLAYER1_LEFT) == true) then
						this.nextCursorPosition_ = this.nextCursorPosition_ - 1
					end
				else
					if (Input.GetTrigger(Input.PLAYER2_RIGHT) == true) then
						this.nextCursorPosition_ = this.nextCursorPosition_ + 1
					elseif (Input.GetTrigger(Input.PLAYER2_LEFT) == true) then
						this.nextCursorPosition_ = this.nextCursorPosition_ - 1
					end					
				end
				
				-- カーソルの移動範囲を制限
				if(this.nextCursorPosition_ < 0) then
					this.nextCursorPosition_ = 0
				elseif(this.nextCursorPosition_ > 1) then
					this.nextCursorPosition_ = 1
				end
			end
			
			this:CheckSmoke()	-- 目隠し用の雲の監視
			
			
			-- 以降がメインシーケンス
			if(this.sequence_ == StateId.RewardPanel_) then
				-- 決定ボタンの受付				
				if(g_joinSide_ == 1) then
					if (this.timer_ > 300 and (Input.GetTrigger(Input.PLAYER1_OK) == true or Input.GetTrigger(Input.PLAYER1_CANCEL) == true)) then
						this.isDecide_ = true
						this.timer_ = 0
					end
				else
					if (this.timer_ > 300 and (Input.GetTrigger(Input.PLAYER2_OK) == true or Input.GetTrigger(Input.PLAYER2_CANCEL) == true)) then
						this.isDecide_ = true
						this.timer_ = 0
					end					
				end
				
				-- 決定ボタンが押されるか、一定時間経過後に実行				
				if(this.isDecide_ == true or this.timer_ > 3600) then				
					Debug.PrintString("決定が押されました")
					this.timer_ = 0
					this.isDecide_ = false
					this.rewardPanelMc_.choice_button.blink_instance:GotoAndPlay("decide")
					this.rewardPanelMc_.choice_button.cursor_mc:GotoAndPlay("decide")
					this.rewardPanelMc_:GotoAndPlay("end")
					--this.controlGuideRMc_:GotoAndPlay("end")
					this.controlGuideLMc_:GotoAndPlay("end")
					-- ごほうびがイベントごほうびなら、イベントごほうび獲得ウィンドウも消す
					if(this.rewardTokenIdList_[this.rewardIndex_] > 999) then
						-- this.eventTokenBgMc_:EndDisplayEventReward()
					end

					-- 勝利数ウィンドウを消す
					this.sectionMain_:EndTotalWinCount()
					
					TSound:Play("se_common_v12a","don_c")
					
					this.sequence_ = StateId.JudgeNextScene_
				end


			elseif(this.sequence_ == StateId.JudgeNextScene_) then
				if(this.timer_ > 100) then
					this.timer_ = 0
					this.currentCursorPosition_ = 0
					this.nextCursorPosition_ = 0
					this.rewardChoicePanelMc_.reward_choice_button:GotoAndStop("left")
					this.rewardChoicePanelMc_.reward_choice_button.button_yes_instance:GotoAndStop("color_1p")
					this.rewardChoicePanelMc_.reward_choice_button.button_no_instance:GotoAndStop("color_2p")
				
					-- もしごほうびが「称号」なら実行
					if(this.rewardTypeList_[this.rewardIndex_] == 0) then
						-- テキストを初期化
						this.rewardChoicePanelMc_.reward_choice_text:SetText("text_choice","result_reward_use")	

						-- TODO:フラッシュになかったのでコメントアウト
						--this.rewardChoicePanelMc_.reward_choice_text.text_reward:SetText("text_title",this.rewardNameKeyList_[this.rewardIndex_])	

						-- 付け替える前の元の称号を取得しておく 【!!!注意!!!】c++への問い合わせは、左太鼓：0、右太鼓：1　で行います
						if(g_joinSide_ == 1) then
							this.oldTitle_ = PlayDataManager.GetUserTitle(0)
							this.oldTitleBaseId_ = PlayDataManager.GetUserTitleBaseId(0)
						else
							this.oldTitle_ = PlayDataManager.GetUserTitle(1)
							this.oldTitleBaseId_ = PlayDataManager.GetUserTitleBaseId(1)						
						end

						-- 称号を付け替える
						this:ChangeRewardTitle(false)							
						-- ウィンドウを表示開始
						this.rewardChoicePanelMc_:GotoAndPlay("start")
						this.rewardChoicePanelMc_.reward_choice_button.cursor_mc:GotoAndPlay("start")

						--this.controlGuideRMc_.guide_taiko_mc:GotoAndStop("choice_decide")
						--this.controlGuideRMc_:GotoAndPlay("start")
						this.controlGuideLMc_.guide_taiko_mc:GotoAndStop("choice_decide")
						this.controlGuideLMc_:GotoAndPlay("start")
						this.sequence_ = StateId.RewardChoicePanel_

						-- サウンド（称号つけかえ）
						--if(this.isUseRight_ == false) then
						--	TSound:Play("se_common_v12a","shogo_change_l")
						--	TSound:Play("se_common_v12a","callout_l")
						--else
						--	TSound:Play("se_common_v12a","shogo_change_r")
						--	TSound:Play("se_common_v12a","callout_r")
						--end
						TSound:Play("se_common_v12a","shogo_change_c")
						TSound:Play("se_common_v12a","callout_c")

					-- もしごほうびが「きせかえ」なら実行
					elseif(this.rewardTypeList_[this.rewardIndex_] < 6) then				
						-- テキストを初期化
						this.rewardChoicePanelMc_.reward_choice_text:SetText("text_choice","result_reward_use")	

						-- TODO:フラッシュになかったのでコメントアウト
						-- this.rewardChoicePanelMc_.reward_choice_text.text_reward:SetText("text_title",this.rewardNameKeyList_[this.rewardIndex_])													

						-- マイドンを着せ替える
						this:ChangeRewardCostume()
						this.mcL_.don_smoke:GotoAndPlay("smoke_in")
						this.isDonSmoke_ = true
						-- ウィンドウを表示開始
						this.rewardChoicePanelMc_:GotoAndPlay("start")
						this.rewardChoicePanelMc_.reward_choice_button.cursor_mc:GotoAndPlay("start")
						this.controlGuideLMc_.guide_taiko_mc:GotoAndStop("choice_decide")
						this.controlGuideLMc_:GotoAndPlay("start")
						this.sequence_ = StateId.RewardChoicePanel_
						-- サウンド（きせかえ付け替え）
						--if(this.isUseRight_ == false) then
						--	TSound:Play("se_common_v12a","costume_change_l")
						--	TSound:Play("se_common_v12a","callout_l")
						--else
						--	TSound:Play("se_common_v12a","costume_change_r")
						--	TSound:Play("se_common_v12a","callout_r")
						--end
						TSound:Play("se_common_v12a","costume_change_c")
						TSound:Play("se_common_v12a","callout_c")
					-- それ以外の場合は再びUpdateRewardPanel 実行
					else
						this.rewardIndex_ = this.rewardIndex_ + 1
						this:UpdateRewardPanel(this.targetRewardTokenId_, false)
					end
				end

			elseif(this.sequence_ == StateId.RewardChoicePanel_) then
				-- 一定時間経過後、カーソル移動を許可
				if(this.timer_ > 300) then
					this.isEnableMoveCursor_ = true
				end
		
				-- カーソルに動きがあったら実行
				if(this.currentCursorPosition_ ~= this.nextCursorPosition_) then
					this.currentCursorPosition_ = this.nextCursorPosition_
					-- カーソルを移動させつつ、マイドンor称号を付け替える
					if(this.currentCursorPosition_ == 0) then
						this.rewardChoicePanelMc_.reward_choice_button:GotoAndStop("left")
						this.rewardChoicePanelMc_.reward_choice_button.button_yes_instance:GotoAndStop("color_1p")
						this.rewardChoicePanelMc_.reward_choice_button.button_no_instance:GotoAndStop("color_2p")
						--　称号を付け替える
						if(this.rewardTypeList_[this.rewardIndex_] == 0) then
							this:ChangeRewardTitle(false)
							-- サウンド（称号つけかえ）
							--if(this.isUseRight_ == false) then
							--	TSound:Play("se_common_v12a","katsu_l")
							--	TSound:Play("se_common_v12a","shogo_change_l")
							--else
							--	TSound:Play("se_common_v12a","katsu_r")
							--	TSound:Play("se_common_v12a","shogo_change_r")
							--end
							TSound:Play("se_common_v12a","katsu_c")
							TSound:Play("se_common_v12a","shogo_change_c")
						-- きせかえを着せ替える
						elseif(this.rewardTypeList_[this.rewardIndex_] < 6) then
							this:ChangeRewardCostume()
							this.mcL_.don_smoke:GotoAndPlay("smoke_in")
							this.isDonSmoke_ = true
							-- サウンド（きせかえ付け替え）
							--if(this.isUseRight_ == false) then
							--	TSound:Play("se_common_v12a","katsu_l")
							--	TSound:Play("se_common_v12a","costume_change_l")
							--else
							--	TSound:Play("se_common_v12a","katsu_r")
							--	TSound:Play("se_common_v12a","costume_change_r")
							--end
							TSound:Play("se_common_v12a","katsu_c")
							TSound:Play("se_common_v12a","costume_change_c")
						end
					elseif(this.currentCursorPosition_ == 1) then
						this.rewardChoicePanelMc_.reward_choice_button:GotoAndStop("right")	
						this.rewardChoicePanelMc_.reward_choice_button.button_yes_instance:GotoAndStop("color_2p")
						this.rewardChoicePanelMc_.reward_choice_button.button_no_instance:GotoAndStop("color_1p")
						--　称号を元に戻す
						if(this.rewardTypeList_[this.rewardIndex_] == 0) then
							this:ChangeRewardTitle(true)
							-- サウンド（称号つけかえ）
							--if(this.isUseRight_ == false) then
							--	TSound:Play("se_common_v12a","katsu_l")
							--	TSound:Play("se_common_v12a","shogo_change_l")
							--else
							--	TSound:Play("se_common_v12a","katsu_r")
							--	TSound:Play("se_common_v12a","shogo_change_r")
							--end
							TSound:Play("se_common_v12a","katsu_c")
							TSound:Play("se_common_v12a","shogo_change_c")
						-- きせかえを元に戻す
						elseif(this.rewardTypeList_[this.rewardIndex_] < 6) then
							Don.ChangeDonForPlayDataOnly(0)
							this.mcL_.don_smoke:GotoAndPlay("smoke_in")
							this.isDonSmoke_ = true
							-- サウンド（きせかえ付け替え）
							--if(this.isUseRight_ == false) then
							--	TSound:Play("se_common_v12a","katsu_l")
							--	TSound:Play("se_common_v12a","costume_change_l")
							--else
							--	TSound:Play("se_common_v12a","katsu_r")
							--	TSound:Play("se_common_v12a","costume_change_r")
							--end	
							TSound:Play("se_common_v12a","katsu_c")
							TSound:Play("se_common_v12a","costume_change_c")
						end
					end
				end
	
				-- 決定ボタンの受付
				if(g_joinSide_ == 1) then
					if (this.timer_ > 300 and (Input.GetTrigger(Input.PLAYER1_OK) == true or Input.GetTrigger(Input.PLAYER1_CANCEL) == true)) then
						this.isDecide_ = true
					end
				else
					if (this.timer_ > 300 and (Input.GetTrigger(Input.PLAYER2_OK) == true or Input.GetTrigger(Input.PLAYER2_CANCEL) == true)) then
						this.isDecide_ = true
					end					
				end
				
				-- 決定ボタンが押されるか、一定時間経過後に実行
				if(this.isDecide_ == true or this.timer_ > 3600) then
					this.timer_ = 0
					this.isEnableMoveCursor_ = false
					this.isDecide_ = false
					this.rewardChoicePanelMc_.reward_choice_button.cursor_mc:GotoAndPlay("decide")
					this.rewardChoicePanelMc_.reward_choice_button.blink_instance:GotoAndPlay("decide")
					this.rewardChoicePanelMc_:GotoAndPlay("end")
					this.controlGuideLMc_:GotoAndPlay("end")
					this.sequence_ = StateId.ChangePlayerInfo_
					
					-- サウンド（決定）
					--if(this.isUseRight_ == false) then
					--	TSound:Play("se_common_v12a","don_l")
					--else
					--	TSound:Play("se_common_v12a","don_r")
					--end
					TSound:Play("se_common_v12a","don_c")
					
					if(this.rewardTypeList_[this.rewardIndex_] == 0) then	-- ごほうびが「称号」の場合
						if(this.currentCursorPosition_ == 0) then
							Don.SetNonLoopAnimation(0,"don_full_combo",true)	-- マイドンにリアクションさせる
							-- サウンド（喜びボイス）
							--if(this.isUseRight_ == false) then
							--	TSound:Play("voice_common_v12a", "glad_l")
							--else
							--	TSound:Play("voice_common_v12a", "glad_r")
							--end
							TSound:Play("voice_common_v12a", "glad_c")
						end
					else													-- ごほうびが「きせかえ」の場合	
						-- 「はい」ならユーザー情報を現在の着せ替え情報で書き換え
						if(this.currentCursorPosition_ == 0) then
							-- 【！！！注意！！！】　着せ替え情報はプレイ人数に関わらず、左側の太鼓：0、右側の太鼓：1、になります！
							if(g_joinSide_ == 2) then
								PlayDataManager.SetCostume(1, this.currentCostume_)
							else
								PlayDataManager.SetCostume(0, this.currentCostume_)
							end

							Don.SetNonLoopAnimation(0,"don_full_combo",true)	-- マイドンにリアクションさせる
							-- サウンド（喜びボイス）
							--if(this.isUseRight_ == false) then
							--	TSound:Play("voice_common_v12a", "glad_l")
							--else
							--	TSound:Play("voice_common_v12a", "glad_r")
							--end
							TSound:Play("voice_common_v12a", "glad_c")
							this.mcL_.don_kira:GotoAndPlay("kira_in")
						end
					end
				end
			elseif(this.sequence_ == StateId.ChangePlayerInfo_) then
				if(this.timer_ > 200) then								
					Don.SetLoopAnimation(0, "result_loop", true)			-- マイドンを待機モーションに戻す
					this.rewardIndex_ = this.rewardIndex_ + 1
					this:UpdateRewardPanel(this.targetRewardTokenId_, false)
				end

			elseif(this.sequence_ == StateId.LoadNextReward_) then
				if(this.timer_ > 100 and this.isUpdateNoticeReward_ == false) then
					if(g_aiNoticeRewardNum == 0) then
						-- 次にもらえるご褒美が無い場合、飛ばす
						this.sequence_ = StateId.End_

					elseif(g_aiWinCountComplete == true) then
						-- イベントトークンがカンストの場合はカンストインフォを表示
						-- this.kanstInfoMc_:GotoAndPlay("start")
						-- this.kanstInfoMc_.achieve_caption:GotoAndStop("event_token_kanst")
						-- this.kanstInfoMc_.text_token_info:SetText("text_info","result_event_token_kanst")
						-- this.kanstInfoMc_.achieve_caption.text_reward_midasi01.text_title1:SetText("text_1","result_event_token_kanst_caption")
						-- this.kanstInfoMc_.achieve_caption.text_reward_midasi01.text_title2:SetText("text_2","result_event_token_kanst_caption")
						-- -- サウンド
						-- if(this.isUseRight_ == false) then
						-- 	TSound:Play("se_common_v12a","gohoubi_get_l")
						-- 	TSound:Play("se_result_v12a","reward_ribbon_l")
						-- else
						-- 	TSound:Play("se_common_v12a","gohoubi_get_r")
						-- 	TSound:Play("se_result_v12a","reward_ribbon_r")				
						-- end
					else
						-- そうでない場合は次に貰えるごほうびお知らせウィンドウを表示
						Debug.PrintString("[AiResultWinCountReward] this.sequence_ == StateId.LoadNextReward_")
						this.eventRewardNoticeMc_:GotoAndPlay("start")
						this.eventRewardNoticeMc_.text_next_reward:SetText("text_token_event_02","result_reward_next")
						-- サウンド（ポップアップ）
						--if(this.isUseRight_ == false) then
						--	TSound:Play("se_common_v12a","popup_l")
						--else
						--	TSound:Play("se_common_v12a","popup_r")
						--end
						TSound:Play("se_common_v12a","popup_c")
					end
					this.isUpdateNoticeReward_ = true
				end
			
				if(this.timer_ > 800) then
					this.timer_ = 0
					-- 既に表示されているものは消す
					if(g_aiWinCountComplete == true) then
						--this.kanstInfoMc_:GotoAndPlay("end")
						---- カンストの場合はイベントトークンをカンスト表記に切り替える
						--this.eventTokenMc_:GotoAndStop("comp")
						--this.eventTokenMc_.text_token_comp:SetText("text","token_complete")
						--this.eventTokenBgMc_:ChangeKanstEventToken()
					else
						this.eventRewardNoticeMc_:GotoAndPlay("end")
						this.eventTokenMc_:GotoAndPlay("stop")
					end

					-- 次のごほうびまでの勝利数表示を変更する
					this.nextRewardNum_:DirectCounter(this.rewardNoticeTokenNeedPointList_[1] - g_winCount_)

					-- 内容を更新して、イベントトークンウィンドウを再表示する
					--this:UpdateNoticeReward(true)
					--this.mc_:GotoAndPlay("change_event")
					--this.eventTokenBgMc_:StartDisplayEventToken()
					--this.eventTokenMc_.add_token_num:SetVisible(false)
					--this.eventTokenMc_.add_token_bg:SetVisible(false)
					this.sequence_ = StateId.End_
				end
			elseif(this.sequence_ == StateId.End_) then
				this.isRewardPanelEnd_ = true
			end
		end,
		-- ここまでUpdate()
		
		-- 全処理完了フラグのゲット関数
		GetIsRewardPanelEnd = function(this)
			return this.isRewardPanelEnd_
		end,
		
		-- ごほうびパネルの更新開始指示
		--[[
		targetRewardTokenId :　トークンID。このIDと紐づいたごほうびのみを表示
		isReset 			: リセットフラグ。trueの場合 rewardIndex を初期化し、ごほうびリストを最初から検索する。falseの場合は1つ前に表示したごほうびの次から検索する。
		]]--
		UpdateRewardPanel = function(this, targetRewardTokenId, isReset)
			this.targetRewardTokenId_ = targetRewardTokenId
			-- isReset がtrueの場合、リザルトインデックスとごほうび終了フラグをリセットする
			if(isReset == true) then
				this.rewardIndex_ = 1
				this.isRewardPanelEnd_ = 0
			end

			-- 引数で指定されたトークンIDに該当するごほうびが存在するか確認し、あれば実行
			if(this:IsCheckTargetReward() == true) then
				this.timer_ = 0
				this.sequence_ = StateId.RewardPanel_			
				this.rewardPanelMc_:GotoAndPlay("start")
				this.rewardPanelMc_.choice_button:GotoAndStop("center")
				this.rewardPanelMc_.choice_button.cursor_mc:GotoAndPlay("start")
				
				local isEvent = false	-- これから表示するごほうびがイベントごほうびか否か
				if(this.rewardTokenIdList_[this.rewardIndex_] > 999) then
					isEvent = true
					this.rewardPanelMc_.reward_panel_bg:SetVisible(true)
					-- this.eventTokenBgMc_:StartDisplayEventReward()
					-- this.eventTokenBgMc_:EndDisplayEventReward()
				end

				--TSound:Play("se_common_v12a","gohoubi_get_c")
				--TSound:Play("se_result_v12a","reward_ribbon_c")

				TSound:Play("se_airesult_v12g","wagara_window_open")

				-- 操作ガイドの表示
				this.controlGuideLMc_.guide_taiko_mc:GotoAndStop("decide")
				this.controlGuideLMc_:GotoAndPlay("start")
				--this.controlGuideRMc_.guide_taiko_mc:GotoAndStop("decide")
				--this.controlGuideRMc_:GotoAndPlay("start")

				-- キャプションの初期化
				-- キャプション背景画像は、通常ごほうびなら rewardMessageList_ に従い、イベントごほうびなら消す
				if(isEvent == false) then
					this.rewardPanelMc_.achieve_caption:GotoAndStop(this.rewardMessageList_[this.rewardIndex_])
				else
					this.rewardPanelMc_.achieve_caption:GotoAndStop("none")
				end

				this.rewardPanelMc_.achieve_caption.text_reward_midasi01.text_title1:SetText("text_1",this.rewardMessageList_[this.rewardIndex_])
				this.rewardPanelMc_.achieve_caption.text_reward_midasi01.text_title2:SetText("text_2", this.rewardMessageList_[this.rewardIndex_])

				-- ごほうびの種類の初期化
				if(this.rewardTypeList_[this.rewardIndex_] == 0) then		-- 称号の場合
					this.rewardPanelMc_.reward_panel_jnl:GotoAndStop("shogo")
					this.rewardPanelMc_.reward_panel_jnl:SetText("text_jnl","result_reward_title")
				elseif(this.rewardTypeList_[this.rewardIndex_] >= 1 and this.rewardTypeList_[this.rewardIndex_] <= 5) then	-- きせかえの場合
					this.rewardPanelMc_.reward_panel_jnl:GotoAndStop("cos")
					this.rewardPanelMc_.reward_panel_jnl:SetText("text_jnl","result_reward_costume_"..this.rewardTypeList_[this.rewardIndex_])
				elseif(this.rewardTypeList_[this.rewardIndex_] == 6) then	-- 楽曲の場合
					this.rewardPanelMc_.reward_panel_jnl:GotoAndStop("song")
					this.rewardPanelMc_.reward_panel_jnl:SetText("text_jnl","result_reward_song")
				elseif(this.rewardTypeList_[this.rewardIndex_] == 7) then	-- 音色の場合
					this.rewardPanelMc_.reward_panel_jnl:GotoAndStop("tone")
					this.rewardPanelMc_.reward_panel_jnl:SetText("text_jnl","result_reward_instrumental")			
				end

				this.rewardPanelMc_.reward_panel_bg:GotoAndStop("next_reward")

				-- ごほうび名の初期化
				this.rewardPanelMc_.reward_panel_jnl.text_reward:SetText("text_title",this.rewardNameKeyList_[this.rewardIndex_])

			-- なければ次のご褒美の告知
			else
				Debug.PrintString("[AiResultWinCountReward] Next StateId.LoadNextReward_")
				-- this.sequence_ = StateId.End_
				this.sequence_ = StateId.LoadNextReward_
			end

		end,
		
		-- 獲得した称号を装備
		-- isReset  :  trueなら元の内容に戻す、falseなら獲得した称号に付け替え
		ChangeRewardTitle = function(this, isReset)
			this.mcL_.syogo_smoke:GotoAndPlay("smoke_in")
			local playerIndex = g_joinSide_ -1	-- 左側の太鼓：0、右側の太鼓：1
			if(isReset == false) then			
				PlayDataManager.SetUserTitle(playerIndex, this.rewardUniqueIdList_[this.rewardIndex_], this.rewardValueList_[this.rewardIndex_])
			else
				PlayDataManager.SetUserTitleStr(playerIndex, this.oldTitle_, this.oldTitleBaseId_)
			end
			this.namePlate_:SetPlayerInfoAI(g_joinSide_)
		end,

		-- 獲得したきせかえを装備(1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ)
		ChangeRewardCostume = function(this)
			-- 獲得したパーツによって以下の2パターンに分岐
			-- きぐるみなら　：　きぐるみ以外のパーツをデフォルトに
			-- きぐるみ以外なら ：　きぐるみをデフォルトに変更
			if(this.rewardTypeList_[this.rewardIndex_] == 5) then
				this.currentCostume_.kigurumi = this.rewardValueList_[this.rewardIndex_]
				this.currentCostume_.head = 0
				this.currentCostume_.body = 0
				this.currentCostume_.face = 0
				this.currentCostume_.puchi = 0
			else
				-- まず現在のきせかえ情報を取得
				if(g_joinSide_ == 1) then
					this.currentCostume_ = PlayDataManager.GetUserClothes(0)
				else
					this.currentCostume_ = PlayDataManager.GetUserClothes(1)
				end
				this.currentCostume_.kigurumi = 0	-- きぐるみはリセット
				-- その後獲得したきせかえをセット	
				if(this.rewardTypeList_[this.rewardIndex_] == 1) then
					this.currentCostume_.head = this.rewardValueList_[this.rewardIndex_]
				elseif(this.rewardTypeList_[this.rewardIndex_] == 2) then
					this.currentCostume_.body = this.rewardValueList_[this.rewardIndex_]
				elseif(this.rewardTypeList_[this.rewardIndex_] == 3) then
					this.currentCostume_.face = this.rewardValueList_[this.rewardIndex_]
				elseif(this.rewardTypeList_[this.rewardIndex_] == 4) then
					this.currentCostume_.puchi = this.rewardValueList_[this.rewardIndex_]
				end
			end
			
			Don.ChangeCostume(0, this.currentCostume_)	-- 作成したcurrentCostume_をマイドンに反映
		end,
		
		-- 目隠し用の雲の監視
		CheckSmoke = function(this)
			-- 雲が出ている場合、読み込みが完了し次第消す
			if(this.isDonSmoke_ == true) then
				if(Don.IsLoadedDon(0) == true) then
					this.mcL_.don_smoke:GotoAndPlay("smoke_out")
					this.isDonSmoke_ = false
				end
			end
		end,
		
		-- 
		IsCheckTargetReward = function(this)
			Debug.PrintString("テスト2")
			if(g_aiGetRewardNum <= 0)then
				return false
			end

			-- 対象となるトークンIDと紐づいたごほうびを探す
			for idx = this.rewardIndex_, g_aiGetRewardNum do
				-- 該当するごほうびが存在したら実行
				if(this.rewardTokenIdList_[idx] == this.targetRewardTokenId_) then
					this.rewardIndex_ = idx
					do
						break
					end
				end
			end
			
			-- 該当するごほうびが見つかっていたらtrueを、そうでなければfalseを返す
			if(this.rewardTokenIdList_[this.rewardIndex_] == this.targetRewardTokenId_) then
				return true
			else
				return false
			end
		end,

		-- 予告ごほうび情報の更新
		-- isUseRewardNoticeList : RewardNoticeListの内容で更新するか否か。falseの場合は RewardList　（つまりこれから獲得処理を行うごほうび）の情報で更新
		UpdateNoticeReward = function(this, isUseRewardNoticeList)
			Debug.PrintString("[AiResultWinCountToken] UpdateNoticeReward")
			--ついでに、次のごほうび予告ウィンドウも初期化
			if(g_aiNoticeRewardNum >= 1) then	-- ｃ++から受け取った予告ごほうび情報の個数が0以下だったらやらない ※将来的にはthis.rewardIndex_を元に、予告ごほうび情報が存在するか否かをキチンと確認してください
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

				-- ウィンドウの背景を変更
				this.eventRewardNoticeMc_.reward_panel_bg:GotoAndStop("next_reward")

				-- ごほうび名の初期化
				this.eventRewardNoticeMc_.reward_panel_jnl.text_reward:SetText("text_title",this.rewardNoticeNameKeyList_[1])
			end
		end,
	}
end

