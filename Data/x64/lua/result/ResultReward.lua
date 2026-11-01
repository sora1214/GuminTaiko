-- ごほうびウィンドウ

local StateId = {
	Init_				= 0,
	RewardPanel_ 		= 1,
	JudgeNextScene_		= 2,
	RewardChoicePanel_	= 3,
	ChangePlayerInfo_	= 4,
	End_				= 99,
}

ResultReward = {}
function ResultReward.New(name)
	return
	{	
		name_ = name,
		mc_,						-- このMC
		rewardPanelMc_,				-- ごほうびパネルMC
		rewardChoicePanelMc_,		-- ごほうび選択MC
		namePlate_,					-- ネームプレートMC
		eventTokenBgMc_,			-- イベントごほうび背景MC
		controlGuideMc_,			-- 操作ガイドMC

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
		currentCursorPosition_,		-- 現在のカーソル位置
		nextCursorPosition_,		-- 次のカーソル位置
		currentCostume_,			-- 現在のきせかえ情報
		oldTitle_ = "",				-- 変更前の称号文字列
		oldTitleBaseId_ = 0,		-- 変更前の称号板ID
		isDonSmoke_ = false,		-- マイドンの上に雲が発生しているか否か
		isDecide_ = false,			-- 決定ボタンが押されたか否か
		isEnableMoveCursor_ = false,-- カーソル移動を受け付けているか否か
		isRewardPanelEnd_ = false,	-- ごほうびパネルの全処理が完了したか否か
		isChara_ = false,			-- コラボキャラ/非表示
		isCharaOnly_ = false,		-- コラボキャラのみ表示する（どんちゃんが表示されない）場合true
		
		Init = function(this, mc, playerIndex, namePlate, eventTokenBg, isChara, isCharaOnly)
			Debug.PrintString("!!!ResultReward Initialize!!!@"..this.name_)
			Lumen.Play()
			this.mc_ = mc
			this.rewardPanelMc_ = this.mc_:GetChildMc("reward_panel",true)
			this.rewardPanelMc_.choice_button.btn_text_3:SetText("text_btn","result_next")
			this.rewardChoicePanelMc_ = this.mc_:GetChildMc("reward_choice_panel",true)
			this.rewardChoicePanelMc_.reward_choice_button.btn_text_1:SetText("text_btn","result_yes")
			this.rewardChoicePanelMc_.reward_choice_button.btn_text_2:SetText("text_btn","result_no")
			this.player_ = playerIndex
			this.namePlate_ = namePlate
			this.eventTokenBgMc_ = eventTokenBg
			this.isChara_ = isChara
			this.isCharaOnly_ = isCharaOnly

			if(playerIndex == 1 and (g_entryType == 0 or g_entryType == 2)) then
				this.isUseRight_ = false
			else
				this.isUseRight_ = true
			end
			
			-- 現在のきせかえ情報を取得
			if(this.isUseRight_ == false) then
				this.currentCostume_ = PlayDataManager.GetUserClothes(0)
			else
				this.currentCostume_ = PlayDataManager.GetUserClothes(1)
			end

			
			if(playerIndex == 1) then
				this.rewardTypeList_ = g_rewardType1p
				this.rewardUniqueIdList_ = g_rewardUniqueId1p
				this.rewardMessageList_ = g_rewardMessage1p
				this.rewardValueList_ = g_rewardValue1p
				this.rewardNameKeyList_ = g_rewardNameKey1p
				this.rewardTokenIdList_ = g_rewardTokenId1p
			else
				this.rewardTypeList_ = g_rewardType2p
				this.rewardUniqueIdList_ = g_rewardUniqueId2p
				this.rewardMessageList_ = g_rewardMessage2p
				this.rewardValueList_ = g_rewardValue2p
				this.rewardNameKeyList_ = g_rewardNameKey2p
				this.rewardTokenIdList_ = g_rewardTokenId2p
			end
		end,
		
		
		-- 操作ガイドの初期化
		InitControlGuide = function(this, controlGuideMc)
			this.controlGuideMc_ = controlGuideMc:GetChildMc("main",true)
			-- テキストの初期化
			this.controlGuideMc_.guide_taiko_mc.select_instance.text_guide_instance:SetText("text_guide","select")
			this.controlGuideMc_.guide_taiko_mc.decide_instance.text_guide_instance:SetText("text_guide","decide")
		end,
		
		
		
		Update = function(this)
			this.timer_ = this.timer_ + 1
			
			-- キー入力処理(左右の太鼓を判別してカーソル移動)
			if(this.sequence_ == StateId.RewardChoicePanel_ and this.isEnableMoveCursor_ == true) then
				if(this.isUseRight_ == false) then
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
				if(this.isUseRight_ == false) then
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
					this.timer_ = 0
					this.isDecide_ = false
					this.rewardPanelMc_.choice_button.blink_instance:GotoAndPlay("decide")
					this.rewardPanelMc_.choice_button.cursor_mc:GotoAndPlay("decide")
					this.rewardPanelMc_:GotoAndPlay("end")
					this.controlGuideMc_:GotoAndPlay("end")
					-- ごほうびがイベントごほうびなら、イベントごほうび獲得ウィンドウも消す
					if(this.rewardTokenIdList_[this.rewardIndex_] > 999) then
						this.eventTokenBgMc_:EndDisplayEventReward()
					end
					
					-- サウンド（決定）
					if(this.isUseRight_ == false) then
						TSound:Play("se_common_v12a","don_l")
					else
						TSound:Play("se_common_v12a","don_r")
					end
					
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
						if(this.isCharaOnly_ == true)then
							this.rewardChoicePanelMc_.reward_choice_text:SetText("text_choice","result_reward_use_event_only")		-- イベントキャラのみ表示時
						else
							this.rewardChoicePanelMc_.reward_choice_text:SetText("text_choice","result_reward_use")
						end
						this.rewardChoicePanelMc_.reward_choice_text.text_reward:SetText("text_title",this.rewardNameKeyList_[this.rewardIndex_])

						-- 付け替える前の元の称号を取得しておく 【!!!注意!!!】c++への問い合わせは、左太鼓：0、右太鼓：1　で行います
						if(this.isUseRight_ == false) then
							this.oldTitle_ = PlayDataManager.GetUserTitle(0)
							this.oldTitleBaseId_ = PlayDataManager.GetUserTitleBaseId(0)
						else
							this.oldTitle_ = PlayDataManager.GetUserTitle(1)
							this.oldTitleBaseId_ = PlayDataManager.GetUserTitleBaseId(1)						
						end

						-- 称号を付け替える
						this:ChangeRewardTitle(false)							
						-- ウィンドウの設定
						if(this.isCharaOnly_ == true)then
							this.rewardChoicePanelMc_.reward_panel_bg:GotoAndStop("event_only")		-- イベントキャラのみ表示時
						else
							this.rewardChoicePanelMc_.reward_panel_bg:GotoAndStop("don")
						end
						-- ウィンドウを表示開始
						this.rewardChoicePanelMc_:GotoAndPlay("start")
						this.rewardChoicePanelMc_.reward_choice_button.cursor_mc:GotoAndPlay("start")
						this.controlGuideMc_.guide_taiko_mc:GotoAndStop("choice_decide")
						this.controlGuideMc_:GotoAndPlay("start")				
						this.sequence_ = StateId.RewardChoicePanel_
						-- サウンド（称号つけかえ）
						if(this.isUseRight_ == false) then
							TSound:Play("se_common_v12a","shogo_change_l")
							TSound:Play("se_common_v12a","callout_l")
						else
							TSound:Play("se_common_v12a","shogo_change_r")
							TSound:Play("se_common_v12a","callout_r")
						end
						
					-- もしごほうびが「きせかえ」なら実行(コラボキャラが表示されている場合、変更演出はスルーする)
					elseif(this.rewardTypeList_[this.rewardIndex_] < 6 and this.isChara_ == false) then				
						-- テキストを初期化
						this.rewardChoicePanelMc_.reward_choice_text:SetText("text_choice","result_reward_use")	
						this.rewardChoicePanelMc_.reward_choice_text.text_reward:SetText("text_title",this.rewardNameKeyList_[this.rewardIndex_])													
						-- マイドンを着せ替える
						this:ChangeRewardCostume()
						this.mc_.don_smoke:GotoAndPlay("smoke_in")
						this.isDonSmoke_ = true
						-- ウィンドウの設定
						this.rewardChoicePanelMc_.reward_panel_bg:GotoAndStop("don")
						-- ウィンドウを表示開始
						this.rewardChoicePanelMc_:GotoAndPlay("start")
						this.rewardChoicePanelMc_.reward_choice_button.cursor_mc:GotoAndPlay("start")
						this.controlGuideMc_.guide_taiko_mc:GotoAndStop("choice_decide")
						this.controlGuideMc_:GotoAndPlay("start")
						this.sequence_ = StateId.RewardChoicePanel_
						-- サウンド（きせかえ付け替え）
						if(this.isUseRight_ == false) then
							TSound:Play("se_common_v12a","costume_change_l")
							TSound:Play("se_common_v12a","callout_l")
						else
							TSound:Play("se_common_v12a","costume_change_r")
							TSound:Play("se_common_v12a","callout_r")
						end
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
							if(this.isUseRight_ == false) then
								TSound:Play("se_common_v12a","katsu_l")
								TSound:Play("se_common_v12a","shogo_change_l")
							else
								TSound:Play("se_common_v12a","katsu_r")
								TSound:Play("se_common_v12a","shogo_change_r")
							end							
						-- きせかえを着せ替える
						elseif(this.rewardTypeList_[this.rewardIndex_] < 6) then
							this:ChangeRewardCostume()
							this.mc_.don_smoke:GotoAndPlay("smoke_in")
							this.isDonSmoke_ = true
							-- サウンド（きせかえ付け替え）
							if(this.isUseRight_ == false) then
								TSound:Play("se_common_v12a","katsu_l")
								TSound:Play("se_common_v12a","costume_change_l")
							else
								TSound:Play("se_common_v12a","katsu_r")
								TSound:Play("se_common_v12a","costume_change_r")
							end
						end
					elseif(this.currentCursorPosition_ == 1) then
						this.rewardChoicePanelMc_.reward_choice_button:GotoAndStop("right")	
						this.rewardChoicePanelMc_.reward_choice_button.button_yes_instance:GotoAndStop("color_2p")
						this.rewardChoicePanelMc_.reward_choice_button.button_no_instance:GotoAndStop("color_1p")
						--　称号を元に戻す
						if(this.rewardTypeList_[this.rewardIndex_] == 0) then
							this:ChangeRewardTitle(true)
							-- サウンド（称号つけかえ）
							if(this.isUseRight_ == false) then
								TSound:Play("se_common_v12a","katsu_l")
								TSound:Play("se_common_v12a","shogo_change_l")
							else
								TSound:Play("se_common_v12a","katsu_r")
								TSound:Play("se_common_v12a","shogo_change_r")
							end
						-- きせかえを元に戻す
						elseif(this.rewardTypeList_[this.rewardIndex_] < 6) then
							if(g_entryType == 1) then
								Don.ChangeDonForPlayDataOnly(1)
							else
								Don.ChangeDonForPlayDataOnly(this.player_ - 1)
							end
							this.mc_.don_smoke:GotoAndPlay("smoke_in")
							this.isDonSmoke_ = true
							-- サウンド（きせかえ付け替え）
							if(this.isUseRight_ == false) then
								TSound:Play("se_common_v12a","katsu_l")
								TSound:Play("se_common_v12a","costume_change_l")
							else
								TSound:Play("se_common_v12a","katsu_r")
								TSound:Play("se_common_v12a","costume_change_r")
							end							
						end
					end
				end
	
				-- 決定ボタンの受付
				if(this.isUseRight_ == false) then
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
					this.controlGuideMc_:GotoAndPlay("end")
					this.sequence_ = StateId.ChangePlayerInfo_
					
					-- サウンド（決定）
					if(this.isUseRight_ == false) then
						TSound:Play("se_common_v12a","don_l")
					else
						TSound:Play("se_common_v12a","don_r")
					end
					
					if(this.rewardTypeList_[this.rewardIndex_] == 0) then	-- ごほうびが「称号」の場合
						if(this.currentCursorPosition_ == 0) then
							if(g_entryType == 1) then
								Don.SetNonLoopAnimation(1,"don_full_combo",true)	-- マイドンにリアクションさせる
							else
								Don.SetNonLoopAnimation(this.player_ - 1,"don_full_combo",true)	-- マイドンにリアクションさせる
							end
							-- サウンド（喜びボイス）
							if(this.isUseRight_ == false) then
								TSound:Play("voice_common_v12a", "glad_l")
							else
								TSound:Play("voice_common_v12a", "glad_r")
							end
						end
					else													-- ごほうびが「きせかえ」の場合	
						-- 「はい」ならユーザー情報を現在の着せ替え情報で書き換え
						if(this.currentCursorPosition_ == 0) then
							-- 【！！！注意！！！】　着せ替え情報はプレイ人数に関わらず、左側の太鼓：0、右側の太鼓：1、になります！
							if(g_entryType == 1) then
								PlayDataManager.SetCostume(1, this.currentCostume_)
								Don.SetNonLoopAnimation(1,"don_full_combo",true)	-- マイドンにリアクションさせる
							else
								PlayDataManager.SetCostume(this.player_ - 1, this.currentCostume_)
								Don.SetNonLoopAnimation(this.player_ - 1,"don_full_combo",true)	-- マイドンにリアクションさせる
							end

							-- サウンド（喜びボイス）
							if(this.isUseRight_ == false) then
								TSound:Play("voice_common_v12a", "glad_l")
							else
								TSound:Play("voice_common_v12a", "glad_r")
							end
							this.mc_.don_kira:GotoAndPlay("kira_in")
						end
					end
				end	
				

			elseif(this.sequence_ == StateId.ChangePlayerInfo_) then
				if(this.timer_ > 200) then								
					if(g_entryType == 1) then
						Don.SetLoopAnimation(1, "result_loop", true)			-- マイドンを待機モーションに戻す
					else
						Don.SetLoopAnimation(this.player_ - 1, "result_loop", true)			-- マイドンを待機モーションに戻す
					end
					this.rewardIndex_ = this.rewardIndex_ + 1
					this:UpdateRewardPanel(this.targetRewardTokenId_, false)
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
					this.rewardPanelMc_.reward_panel_bg:SetVisible(false)	-- 通常の背景を消し、イベント用の背景を読み込む
					this.eventTokenBgMc_:StartDisplayEventReward()
				end
				
				-- サウンド
				if(this.isUseRight_ == false) then
					TSound:Play("se_common_v12a","gohoubi_get_l")
					TSound:Play("se_result_v12a","reward_ribbon_l")
				else
					TSound:Play("se_common_v12a","gohoubi_get_r")
					TSound:Play("se_result_v12a","reward_ribbon_r")					
				end
				
				-- 操作ガイドの表示
				this.controlGuideMc_.guide_taiko_mc:GotoAndStop("decide")
				this.controlGuideMc_:GotoAndPlay("start")
	
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
--					this.rewardPanelMc_.reward_panel_bg:GotoAndStop("shogo")
					this.rewardPanelMc_.reward_panel_jnl:SetText("text_jnl","result_reward_title")
				elseif(this.rewardTypeList_[this.rewardIndex_] >= 1 and this.rewardTypeList_[this.rewardIndex_] <= 5) then	-- きせかえの場合
					this.rewardPanelMc_.reward_panel_jnl:GotoAndStop("cos")
--					this.rewardPanelMc_.reward_panel_bg:GotoAndStop("cos")
					this.rewardPanelMc_.reward_panel_jnl:SetText("text_jnl","result_reward_costume_"..this.rewardTypeList_[this.rewardIndex_])
				elseif(this.rewardTypeList_[this.rewardIndex_] == 6) then	-- 楽曲の場合
					this.rewardPanelMc_.reward_panel_jnl:GotoAndStop("song")
--					this.rewardPanelMc_.reward_panel_bg:GotoAndStop("song")
					this.rewardPanelMc_.reward_panel_jnl:SetText("text_jnl","result_reward_song")
				elseif(this.rewardTypeList_[this.rewardIndex_] == 7) then	-- 音色の場合
					this.rewardPanelMc_.reward_panel_jnl:GotoAndStop("tone")
--					this.rewardPanelMc_.reward_panel_bg:GotoAndStop("tone")
					this.rewardPanelMc_.reward_panel_jnl:SetText("text_jnl","result_reward_instrumental")			
				end
				-- ごほうび名の初期化
				this.rewardPanelMc_.reward_panel_jnl.text_reward:SetText("text_title",this.rewardNameKeyList_[this.rewardIndex_])
			-- なければ即終了
			else
				this.sequence_ = StateId.End_		
			end
		end,
		
		
		
		
		
		-- 獲得した称号を装備
		-- isReset  :  trueなら元の内容に戻す、falseなら獲得した称号に付け替え
		ChangeRewardTitle = function(this, isReset)
			this.mc_.syogo_smoke:GotoAndPlay("smoke_in")
			local playerIndex = 0	-- 左側の太鼓：0、右側の太鼓：1
			if(this.isUseRight_ == true) then
				playerIndex = 1
			end
			
			if(isReset == false) then			
				PlayDataManager.SetUserTitle(playerIndex, this.rewardUniqueIdList_[this.rewardIndex_], this.rewardValueList_[this.rewardIndex_])
			else
				PlayDataManager.SetUserTitleStr(playerIndex, this.oldTitle_, this.oldTitleBaseId_)
			end
			
			this.namePlate_:SetPlayerInfo(playerIndex + 1)
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
				if(this.isUseRight_ == false) then
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
			if(g_entryType == 1) then
				Don.ChangeCostume(1, this.currentCostume_)	-- 作成したcurrentCostume_をマイドンに反映
			else
				Don.ChangeCostume(this.player_ - 1, this.currentCostume_)	-- 作成したcurrentCostume_をマイドンに反映
			end
		end,
		
		
		
		
		-- 目隠し用の雲の監視
		CheckSmoke = function(this)
			-- 雲が出ている場合、読み込みが完了し次第消す
			if(this.isDonSmoke_ == true) then
				if(g_entryType == 1) then
					if(Don.IsLoadedDon(1) == true) then
						this.mc_.don_smoke:GotoAndPlay("smoke_out")
						this.isDonSmoke_ = false
					end
				else
					if(Don.IsLoadedDon(this.player_ - 1) == true) then
						this.mc_.don_smoke:GotoAndPlay("smoke_out")
						this.isDonSmoke_ = false
					end
				end
			end
		end,
		
		

		
		-- 
		IsCheckTargetReward = function(this)
			-- 対象となるトークンIDと紐づいたごほうびを探す
			for idx = this.rewardIndex_, g_getRewardNum[this.player_] do
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
	}
end

