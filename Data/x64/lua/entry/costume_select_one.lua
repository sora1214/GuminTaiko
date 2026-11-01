require("common.State")

CostumeSelectOnePlayer = {}
function CostumeSelectOnePlayer.New(movieClip,playerId)
	return
	{
		mc_ = movieClip,
		playerId_ = playerId,
		player_num_ = 1,
		finish_flag_ = false,
		finish_state_ = false,
		voice_flag_ = false,
		voice_wait_ = 0,
		state_ = State.New("CostumeSelectOnePlayer_"..playerId),
		wait_upload_ = false,

		Setup = function(this)
			this.mc_:Stop()

			if(this.playerId_ == 1) then
				this.input_right_ = Input.PLAYER1_RIGHT
				this.input_left_ = Input.PLAYER1_LEFT
				this.input_donr_ = Input.PLAYER1_OK
				this.input_donl_ = Input.PLAYER1_CANCEL
			else
				this.input_right_ = Input.PLAYER2_RIGHT
				this.input_left_ = Input.PLAYER2_LEFT
				this.input_donr_ = Input.PLAYER2_OK
				this.input_donl_ = Input.PLAYER2_CANCEL
			end

			this.cursor_idx_ = 1
			this.select_offset_ = 0

			-- デフォルト標準
			this.costume_max_ = 5
			this.costume_index_list_ = {Don.kPreset_Default,Don.kPreset_Cool,Don.kPreset_Cute,Don.kPreset_Joke,Don.kPreset_Coice}

-- テスト用
--			if(this.playerId_ == 2) then
--				this.costume_max_ = 7
--				this.costume_index_list_ = {Don.kPreset_Collabo1,Don.kPreset_Collabo2,Don.kPreset_Default,Don.kPreset_Cool,Don.kPreset_Cute,Don.kPreset_Joke,Don.kPreset_Coice}
--			end

			this.arrow_flag_ = {false,false}

			this:SetupState()

			this.board_mc_ = this.mc_.board_instance
			this.board_mc_:Stop()
			this.board_mc_:SetText("text_title","costume_select")

			this.board_mc_.smoke_instance:GotoAndStop("smoke_in")
			this.smoke_flag_ = false

			this.icon_mc_ = {}
			this.icon_mc_[1] = this.board_mc_.select_instance.icon_instance_1
			this.icon_mc_[2] = this.board_mc_.select_instance.icon_instance_2
			this.icon_mc_[3] = this.board_mc_.select_instance.icon_instance_3
			this.icon_mc_[4] = this.board_mc_.select_instance.icon_instance_4
			this.icon_mc_[5] = this.board_mc_.select_instance.icon_instance_5

			this.arrow_mc_ = {}
			this.arrow_mc_[1] = this.board_mc_.select_instance.arrow_l_instance
			this.arrow_mc_[2] = this.board_mc_.select_instance.arrow_r_instance
			this.arrow_mc_[1]:GotoAndPlay("arrow_on")
			this.arrow_mc_[2]:GotoAndPlay("arrow_on")
			this.arrow_mc_[1]:SetVisible(false)
			this.arrow_mc_[2]:SetVisible(false)

			this.board_mc_.guide_instance.select_instance:SetText("text_guide_instance","text_guide","select")
			this.board_mc_.guide_instance.decide_instance:SetText("text_guide_instance","text_guide","decide")

			-- どん調整
			this:UpdateDon(false)
			-- アイコン調整
			this:UpdateIcon()
		end,
		-- プレイヤー数設定
		SetPlayerNum = function(this,playerNum)
			this.player_num_ = playerNum
		end,
		-- 開始
		Start = function(this)
			this.mc_:GotoAndPlay("fade_in")
			this.finish_flag_ = false

			this:SetVoiceWait((Common.FPS * 2.0))

			-- いろいろ消す
--[[
			for loop_idx = 1,5 do
				this.icon_mc_[loop_idx].cursor_instance:SetVisible(false)
			end
			this.arrow_mc_[1]:SetVisible(false)
			this.arrow_flag_[1] = false
			this.arrow_mc_[2]:SetVisible(false)
			this.arrow_flag_[2] = false
			this.board_mc_.guide_instance:SetVisible(false)
]]

			-- ステート変化
			this.state_:SetState("Begin")

			-- どん調整
			this:UpdateDon(false)
		end,
		StartSelect = function(this)
			-- 消していたのを出す
--[[
			for loop_idx = 1,5 do
				this.icon_mc_[loop_idx].cursor_instance:SetVisible(true)
			end
			this.board_mc_.guide_instance:SetVisible(true)
			this:UpdateIcon()
]]

			-- ステート変化
			this.state_:SetState("SelectCostume")
		end,
		-- 処理済みにする
		SetFinish = function(this)
			this.finish_flag_ = true
		end,
		IsPlay = function(this)
			return this.mc_:IsPlay()
		end,

		-- 時間切れ
		TimeUp = function(this)
			this:Decide()
		end,

		-- 更新
		Update = function(this,isWaitUpload)
			this.wait_upload_ = isWaitUpload

			-- ステート実行
			this.state_:Update()

			return this.finish_flag_
		end,

		SetupState = function(this)
			-- ステートマシンの組み立て
			this.state_.func_["Begin"] = function()
				this.state_:SetState("StartWait")
			end

			this.state_.func_["StartWait"] = function()
--				if(this.mc_:IsPlay() == false) then
--				if(this.state_.count_ >= (Common.FPS * 1.0)) then
--					this.state_:SetState("SelectCostume")
--				end
				-- 煙更新
				this:UpdateSmoke()
			end

			this.state_.func_["SelectCostume"] = function()
				if(this.wait_upload_ == true) then
					return
				end

				-- 決定
				if((Input.GetTrigger(this.input_donr_) == true) or (Input.GetTrigger(this.input_donl_) == true)) then
					if(this.smoke_flag_ == false) then
						if(this.player_num_ == 1) then
							-- ＳＥ「小どん（中央）」
							TSound:Play("se_common_v12a","don_c")
						else
							if(this.playerId_ == 1) then
								-- ＳＥ「小どん（左）」
								TSound:Play("se_common_v12a","don_l")
							else
								-- ＳＥ「小どん（右）」
								TSound:Play("se_common_v12a","don_r")
							end
						end

						this:Decide()
					end
				end
				-- ←
				if(Input.GetTrigger(this.input_left_) == true) then
					if((this.cursor_idx_ + this.select_offset_) > 1) then

						if(this.player_num_ == 1) then
							-- ＳＥ「小かっ（中央）」
							TSound:Play("se_common_v12a","katsu_c")
						else
							if(this.playerId_ == 1) then
								-- ＳＥ「小かっ（左）」
								TSound:Play("se_common_v12a","katsu_l")
							else
								-- ＳＥ「小かっ（右）」
								TSound:Play("se_common_v12a","katsu_r")
							end
						end

						if(this.cursor_idx_ > 1) then
							this.cursor_idx_ = this.cursor_idx_ - 1
						else
							this.select_offset_ = this.select_offset_ - 1
						end

						this:UpdateDon(true)
						this:UpdateIcon()

						this:SetVoiceWait((Common.FPS * 0.5))
					end
				end
				-- →
				if(Input.GetTrigger(this.input_right_) == true) then
					if((this.cursor_idx_ + this.select_offset_) < this.costume_max_) then

						if(this.player_num_ == 1) then
							-- ＳＥ「小かっ（中央）」
							TSound:Play("se_common_v12a","katsu_c")
						else
							if(this.playerId_ == 1) then
								-- ＳＥ「小かっ（左）」
								TSound:Play("se_common_v12a","katsu_l")
							else
								-- ＳＥ「小かっ（右）」
								TSound:Play("se_common_v12a","katsu_r")
							end
						end

						if(this.cursor_idx_ < 5) then
							this.cursor_idx_ = this.cursor_idx_ + 1
						else
							this.select_offset_ = this.select_offset_ + 1
						end

						this:UpdateDon(true)
						this:UpdateIcon()

						this:SetVoiceWait((Common.FPS * 0.5))
					end
				end

				-- 煙更新
				this:UpdateSmoke()
				-- ボイス関連更新
				this:UpdateVoice()
			end

			this.state_.func_["FinishWait"] = function()
				if(this.icon_mc_[this.cursor_idx_].blink_instance:IsPlay() == false) then
					-- 表示消し
					this.board_mc_.select_instance:GotoAndPlay("fade_out")
					this.finish_flag_ = true
				end
			end
		end,

		UpdateIcon = function(this)
			for loop_idx = 1,5 do
				-- アイコン調整
				local list_idx = loop_idx + this.select_offset_
				this.icon_mc_[loop_idx]:GotoAndStop(CostumeSelect.label_list_[(this.costume_index_list_[list_idx] + 1)])

				-- カーソル表示
				if(loop_idx == this.cursor_idx_) then
					this.icon_mc_[loop_idx].cursor_instance:GotoAndStop("cursor_on")
				else
					this.icon_mc_[loop_idx].cursor_instance:GotoAndStop("cursor_off")
				end
			end

			-- 矢印表示
			if((this.select_offset_ + this.cursor_idx_) == 1) then
				-- 左なし
				if(this.arrow_flag_[1] == true) then
					this.arrow_mc_[1]:SetVisible(false)
					this.arrow_flag_[1] = false
				end
			else
				-- 左あり
				if(this.arrow_flag_[1] == false) then
					this.arrow_mc_[1]:SetVisible(true)
					this.arrow_flag_[1] = true
				end
			end
			if((this.select_offset_ + this.cursor_idx_) == this.costume_max_) then
				-- 右なし
				if(this.arrow_flag_[2] == true) then
					this.arrow_mc_[2]:SetVisible(false)
					this.arrow_flag_[2] = false
				end
			else
				-- 右あり
				if(this.arrow_flag_[2] == false) then
					this.arrow_mc_[2]:SetVisible(true)
					this.arrow_flag_[2] = true
				end
			end
		end,
		UpdateDon = function(this,smokeFlag)
			local list_idx = this.cursor_idx_ + this.select_offset_
			Don.ChangePresetDon((this.playerId_ - 1),this.costume_index_list_[list_idx])

			if(smokeFlag == true) then
				this:StartSmoke()
			end
		end,
		StartSmoke = function(this)
			-- 着替え中は煙
			this.board_mc_.smoke_instance:GotoAndPlay("smoke_in")

			if(this.player_num_ == 1) then
				-- ＳＥ「きせかえ変化（中央）」
				TSound:Play("se_common_v12a","costume_change_c")
			else
				if(this.playerId_ == 1) then
					-- ＳＥ「きせかえ変化（左）」
					TSound:Play("se_common_v12a","costume_change_l")
				else
					-- ＳＥ「きせかえ変化（右）」
					TSound:Play("se_common_v12a","costume_change_r")
				end
			end

			this.smoke_flag_ = true
		end,
		UpdateSmoke = function(this)
			if(this.smoke_flag_ == true) then
				if(Don.IsLoadedDon((this.playerId_ - 1)) == true) then
					this.board_mc_.smoke_instance:GotoAndPlay("smoke_out")
					this.smoke_flag_ = false
				end
			end
		end,
		UpdateVoice = function(this)
			if(this.voice_flag_ == true) then
				this.voice_wait_ = this.voice_wait_ - 1
				if(this.voice_wait_ <= 0) then
					-- 種別のボイス
					local list_idx = this.cursor_idx_ + this.select_offset_
					local voice_name = ""
					local voice_flag = false

					if(this.costume_index_list_[list_idx] == Don.kPreset_Cool) then
						voice_flag = true
						voice_name = "costume_kakkoii"
					end
					if(this.costume_index_list_[list_idx] == Don.kPreset_Cute) then
						voice_flag = true
						voice_name = "costume_kawaii"
					end
					if(this.costume_index_list_[list_idx] == Don.kPreset_Joke) then
						voice_flag = true
						voice_name = "costume_omoshiroi"
					end
					if(this.costume_index_list_[list_idx] == Don.kPreset_Coice) then
						voice_flag = true
						voice_name = "costume_random"
					end
					if(voice_flag == true) then
						if(this.player_num_ == 1) then
							TSound:Play("voice_entry_v12a",voice_name.."_c")
						else
							if(this.playerId_ == 1) then
								TSound:Play("voice_entry_v12a",voice_name.."_l")
							else
								TSound:Play("voice_entry_v12a",voice_name.."_r")
							end
						end
					end
					this.voice_flag_ = false
				end
			end
		end,
		SetVoiceWait = function(this,count)
			this.voice_flag_ = true
			if(count > this.voice_wait_) then
				this.voice_wait_ = count
			end
		end,

		-- 決定処理
		Decide = function(this)
			-- カーソルアニメ
			this.icon_mc_[this.cursor_idx_].cursor_instance.cursor_anim_instance:GotoAndPlay("decide")

			-- 点滅
			this.icon_mc_[this.cursor_idx_].blink_instance:GotoAndPlay("decide")

			-- 表示消し
			this.board_mc_:SetText("text_title","")
			this.board_mc_.guide_instance:GotoAndPlay("fade_out")

			local list_idx = this.cursor_idx_ + this.select_offset_
			PlayDataManager.DecideCostumeSelect((this.playerId_ - 1),this.costume_index_list_[list_idx])

			-- ステート変化
			this.state_:SetState("FinishWait")
		end,
	}
end
