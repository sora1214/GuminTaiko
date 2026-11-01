require("common.State")

NameEntryOnePlayer = {}
function NameEntryOnePlayer.New(movieClip,guideMc,playerId)
	return
	{
		mc_ = movieClip,
		guide_mc_ = guideMc,
		playerId_ = playerId,
		player_num_ = 1,
		color_labelname_ = "color_"..playerId.."p",
		return_code_ = NameEntry.EnumReturn.kDoing,
		state_ = State.New("NameEntryOnePlayer_"..playerId),
		wait_upload_ = false,

		Setup = function(this)
			this.mc_:Stop()
			this.guide_mc_:Stop()

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

			this.name_string_ = {" "," "," "," "," "}

			this.bigplate_cursor_idx_ = 1

			this.ring1_idx_ = 1
			this.ring2_idx_ = 1
			this.ring3_idx_ = 1

			this.name_decide_blank_ = false

			this.name_accept_cursor_ = 1

			this:SetupState()

			this.nameinput_mc_ = this.mc_.nameinput_instance
			this.nameinput_mc_:SetText("text_title","name_entry")

			-- 名前確認ウィンドウ
			this.accept_base_mc_ = this.nameinput_mc_.accept_instance
			this.accept_mc_ = this.accept_base_mc_.accept_main_mc
			this.accept_mc_.button_no_instance:GotoAndStop("color_2p")
			this.accept_mc_.button_yes_instance:GotoAndStop("color_1p")
			this.accept_mc_.plate_instance:GotoAndStop(this.color_labelname_)
			this.accept_mc_:SetText("text_message","name_entry_accept")
			this.accept_mc_:SetText("text_yes","result_yes")
			this.accept_mc_:SetText("text_no","result_no")
			this.accept_mc_.text_notice_instance:SetText("text_notice","name_entry_notice")
			this.accept_mc_.guide_instance.select_instance.text_guide_instance:SetText("text_guide","select")
			this.accept_mc_.guide_instance.decide_instance.text_guide_instance:SetText("text_guide","decide")
			this.accept_mc_.guide_instance.base_instance:GotoAndStop("inwindow")
			this.accept_mc_.guide_instance:GotoAndStop("fade_in_end")
			this.accept_base_mc_:SetVisible(false)

			-- 名前ＮＧウィンドウ
			this.ng_mc_ = this.nameinput_mc_.ng_instance
			this.ng_mc_.plate_instance:GotoAndStop(this.color_labelname_)
			this.ng_mc_.plate_instance:SetText("text_message","name_entry_ng")
			this.ng_mc_:SetVisible(false)

			-- 表示用の名前ウィンドウ
			this.dispname_mc_ = this.nameinput_mc_.plate_big_instance
			this.dispname_mc_:GotoAndStop(this.color_labelname_)

			this.dispname_char_mc_ = {}
			this.dispname_char_mc_[1] = this.dispname_mc_.plate_big_1
			this.dispname_char_mc_[2] = this.dispname_mc_.plate_big_2
			this.dispname_char_mc_[3] = this.dispname_mc_.plate_big_3
			this.dispname_char_mc_[4] = this.dispname_mc_.plate_big_4
			this.dispname_char_mc_[5] = this.dispname_mc_.plate_big_5

			this.dispname_char_mc_[1]:GotoAndStop(this.color_labelname_)
			this.dispname_char_mc_[2]:GotoAndStop(this.color_labelname_)
			this.dispname_char_mc_[3]:GotoAndStop(this.color_labelname_)
			this.dispname_char_mc_[4]:GotoAndStop(this.color_labelname_)
			this.dispname_char_mc_[5]:GotoAndStop(this.color_labelname_)

			-- 操作ガイド
			this.guide_mc_.select_instance.text_guide_instance:SetText("text_guide","select")
			this.guide_mc_.decide_instance.text_guide_instance:SetText("text_guide","decide")
			this.guide_mc_.base_instance:GotoAndStop("outwindow")

			-- 名前入力リングの中心表示
			this.centeranim_mc_ = this.nameinput_mc_.center
			this.centeranim_mc_.plate:GotoAndStop(this.color_labelname_)

			-- 名前入力リング
			this.ring1_mc_ = this.nameinput_mc_.ring_1
			this.ring2_mc_ = this.nameinput_mc_.ring_2
			this.ring3_mc_ = this.nameinput_mc_.ring_3
			this.ring2_4_mc_ = this.ring2_mc_.row4
			this.ring2_5_mc_ = this.ring2_mc_.row5
			this.ring2_6_mc_ = this.ring2_mc_.row6
			this.ring3_3_mc_ = this.ring3_mc_.row3
			this.ring3_4_mc_ = this.ring3_mc_.row4

			this.ring2_disp_mc_ = this.ring2_4_mc_
			this.ring3_disp_mc_ = this.ring3_3_mc_

			this.ring1_mc_.plate_1:GotoAndStop(this.color_labelname_)
			this.ring1_mc_.plate_2:GotoAndStop(this.color_labelname_)
			this.ring1_mc_.plate_3:GotoAndStop(this.color_labelname_)
			this.ring1_mc_.plate_4:GotoAndStop(this.color_labelname_)
			this.ring1_mc_.plate_5:GotoAndStop(this.color_labelname_)
			this.ring1_mc_.plate_6:GotoAndStop(this.color_labelname_)
			this.ring1_mc_.plate_7:GotoAndStop(this.color_labelname_)
			this.ring1_mc_.plate_8:GotoAndStop(this.color_labelname_)
			this.ring1_mc_.plate_9:GotoAndStop(this.color_labelname_)
			this.ring1_mc_.plate_10:GotoAndStop(this.color_labelname_)
			this.ring1_mc_.plate_11:GotoAndStop(this.color_labelname_)
			this.ring1_mc_.plate_12:GotoAndStop(this.color_labelname_)
			this.ring1_mc_.plate_13:GotoAndStop(this.color_labelname_)

			this.ring2_4_mc_.plate_1:GotoAndStop(this.color_labelname_)
			this.ring2_4_mc_.plate_2:GotoAndStop(this.color_labelname_)
			this.ring2_4_mc_.plate_3:GotoAndStop(this.color_labelname_)
			this.ring2_4_mc_.plate_4:GotoAndStop(this.color_labelname_)

			this.ring2_5_mc_.plate_1:GotoAndStop(this.color_labelname_)
			this.ring2_5_mc_.plate_2:GotoAndStop(this.color_labelname_)
			this.ring2_5_mc_.plate_3:GotoAndStop(this.color_labelname_)
			this.ring2_5_mc_.plate_4:GotoAndStop(this.color_labelname_)
			this.ring2_5_mc_.plate_5:GotoAndStop(this.color_labelname_)

			this.ring2_6_mc_.plate_1:GotoAndStop(this.color_labelname_)
			this.ring2_6_mc_.plate_2:GotoAndStop(this.color_labelname_)
			this.ring2_6_mc_.plate_3:GotoAndStop(this.color_labelname_)
			this.ring2_6_mc_.plate_4:GotoAndStop(this.color_labelname_)
			this.ring2_6_mc_.plate_5:GotoAndStop(this.color_labelname_)
			this.ring2_6_mc_.plate_6:GotoAndStop(this.color_labelname_)

			this.ring3_3_mc_.plate_1:GotoAndStop(this.color_labelname_)
			this.ring3_3_mc_.plate_2:GotoAndStop(this.color_labelname_)
			this.ring3_3_mc_.plate_3:GotoAndStop(this.color_labelname_)

			this.ring3_4_mc_.plate_1:GotoAndStop(this.color_labelname_)
			this.ring3_4_mc_.plate_2:GotoAndStop(this.color_labelname_)
			this.ring3_4_mc_.plate_3:GotoAndStop(this.color_labelname_)
			this.ring3_4_mc_.plate_4:GotoAndStop(this.color_labelname_)

			-- カーソル位置設定
			this:SetBigplateCursor(this.bigplate_cursor_idx_)
			-- 名前設定
			this:SetNameBigplate()
			-- リング設定
			this:SetDispModeRing1()
		end,
		-- プレイヤー数設定
		SetPlayerNum = function(this,playerNum)
			this.player_num_ = playerNum
		end,
		-- 開始
		Start = function(this)
			this.mc_:GotoAndPlay("fade_in")
			this.guide_mc_:GotoAndPlay("fade_in")
			this.return_code_ = NameEntry.EnumReturn.kDoing
		end,
		StartSelect = function(this)
			-- ステート変化
			this.state_:SetState("Ring1")
		end,
		-- 処理済みにする
		SetFinish = function(this)
			this.return_code_ = NameEntry.EnumReturn.kFinish
		end,

		-- 更新
		Update = function(this,isWaitUpload)
			this.wait_upload_ = isWaitUpload

			-- ステート実行
			this.state_:Update()

			return this.return_code_
		end,

		SetupState = function(this)
			-- ステートマシンの組み立て
			this.state_.func_["Begin"] = function()
				this.state_:SetState("StartWait")
			end

			this.state_.func_["StartWait"] = function()
--				if(this.state_.count_ >= (Common.FPS * 1.0)) then
--					this.state_:SetState("Ring1")
--				end
			end

			this.state_.func_["ToRing1"] = function()
				if(this.nameinput_mc_:IsPlay() == false) then
					-- リングのカーソル表示
					this:SetRingCursor(true)
					this.state_:SetState("Ring1")
				end
			end
			this.state_.func_["Ring1"] = function()
				if(this.wait_upload_ == true) then
					return
				end

				-- 決定
				if((Input.GetTrigger(this.input_donr_) == true) or (Input.GetTrigger(this.input_donl_) == true)) then
					local ring1_code = NameEntry.ring1_list_[this.ring1_idx_][1]
					if(ring1_code == "back") then
						-- 戻る
						-- 空欄にする
						this.name_string_[this.bigplate_cursor_idx_] = " "
						-- １文字戻す
						this.bigplate_cursor_idx_ = this.bigplate_cursor_idx_ - 1
						if(this.bigplate_cursor_idx_ <= 0) then
							this.bigplate_cursor_idx_ = 1
							this.name_string_[this.bigplate_cursor_idx_] = " "
						end

						-- ＳＥ
						this:PlaySECancel()

						-- 名前設定
						this:SetNameBigplate()
						-- リングは「あ行」に戻す
						this.ring1_idx_ = 1
						this:SetupToRing1()
					elseif(ring1_code == "end") then

						-- 空欄は名前を強制設定
						this:ChangeBlankNameToDefaultName()

						-- ＳＥ
						this:PlaySEDon()

						this:SetupToAccept()
						-- 表示調整
--						this.name_accept_cursor_ = 2
--						this:SetDispToAccept()
--						this.state_:SetState("Accept")
					else
						-- ＳＥ
						this:PlaySEDon()

						this.ring2_idx_ = 1
						this:SetupToRing2()
					end
				end
				-- ←
				if(Input.GetTrigger(this.input_left_) == true) then
					this.ring1_idx_ = this.ring1_idx_ - 1
					if(this.ring1_idx_ <= 0) then
						this.ring1_idx_ = #(NameEntry.ring1_list_)
					end

					this.ring1_mc_.cursor_plate:SetVisible(false)
					-- アニメーション
					this.ring1_mc_:GotoAndPlay("left")
					-- ＳＥ
					this:PlaySEKatsu()

					this.state_:SetState("Ring1Move")
				end
				-- →
				if(Input.GetTrigger(this.input_right_) == true) then
					this.ring1_idx_ = this.ring1_idx_ + 1
					if(this.ring1_idx_ > #(NameEntry.ring1_list_)) then
						this.ring1_idx_ = 1
					end

					this.ring1_mc_.cursor_plate:SetVisible(false)
					-- アニメーション
					this.ring1_mc_:GotoAndPlay("right")
					-- ＳＥ
					this:PlaySEKatsu()

					this.state_:SetState("Ring1Move")
				end
			end
			this.state_.func_["Ring1Move"] = function()
				this:SetDispCharPosRing1()
				if(this.ring1_mc_:IsPlay() == false) then
					-- 表示調整
					this:SetDispRing2(true)
					this:SetDispCenter(1)

					this.ring1_mc_.cursor_plate:SetVisible(true)

					this.state_:SetState("Ring1")
				end
			end

			this.state_.func_["ToRing2"] = function()
				if(this.nameinput_mc_:IsPlay() == false) then
					-- リングのカーソル表示
					this:SetRingCursor(true)
					-- リング２へ
					this.state_:SetState("Ring2")
				end
			end
			this.state_.func_["Ring2"] = function()
				if(this.wait_upload_ == true) then
					return
				end

				-- 決定
				if((Input.GetTrigger(this.input_donr_) == true) or (Input.GetTrigger(this.input_donl_) == true)) then
					local ring2_param = NameEntry.ring2_list_[this.ring1_idx_][this.ring2_idx_]
					if(ring2_param[1] == "back") then
						-- ＳＥ
						this:PlaySECancel()

						-- 戻る
						this.ring2_idx_ = 1
						this:SetupToRing1()
					elseif(ring2_param[2] == 0) then
						-- ＳＥ
						this:PlaySEDon()

						-- 文字決定の動き
						this.centeranim_mc_:GotoAndPlay("pos_"..this.bigplate_cursor_idx_)

						-- 文字を入れちゃう
						this.name_string_[this.bigplate_cursor_idx_] = ring2_param[1]

						this.state_:SetState("CharDecide")
					else
						-- ＳＥ
						this:PlaySEDon()

						this.ring3_idx_ = 1
						this:SetupToRing3()
					end
				end
				-- ←
				if(Input.GetTrigger(this.input_left_) == true) then
					this.ring2_idx_ = this.ring2_idx_ - 1
					if(this.ring2_idx_ <= 0) then
						this.ring2_idx_ = #(NameEntry.ring2_list_[this.ring1_idx_])
					end

					this.ring2_disp_mc_.cursor_plate:SetVisible(false)
					-- アニメーション
					this.ring2_disp_mc_:GotoAndPlay("left")
					-- ＳＥ
					this:PlaySEKatsu()

					this.state_:SetState("Ring2Move")
				end
				-- →
				if(Input.GetTrigger(this.input_right_) == true) then
					this.ring2_idx_ = this.ring2_idx_ + 1
					if(this.ring2_idx_ > #(NameEntry.ring2_list_[this.ring1_idx_])) then
						this.ring2_idx_ = 1
					end

					this.ring2_disp_mc_.cursor_plate:SetVisible(false)
					-- アニメーション
					this.ring2_disp_mc_:GotoAndPlay("right")
					-- ＳＥ
					this:PlaySEKatsu()

					this.state_:SetState("Ring2Move")
				end
			end
			this.state_.func_["Ring2Move"] = function()
				this:SetDispCharPosRing2()
				if(this.ring2_disp_mc_:IsPlay() == false) then
					-- 表示調整
					this:SetDispRing3(true)
					this:SetDispCenter(2)

					this.ring2_disp_mc_.cursor_plate:SetVisible(true)

					this.state_:SetState("Ring2")
				end
			end

			this.state_.func_["ToRing3"] = function()
				if(this.nameinput_mc_:IsPlay() == false) then
					-- リングのカーソル表示
					this:SetRingCursor(true)
					-- リング２へ
					this.state_:SetState("Ring3")
				end
			end
			this.state_.func_["Ring3"] = function()
				if(this.wait_upload_ == true) then
					return
				end

				-- 決定
				if((Input.GetTrigger(this.input_donr_) == true) or (Input.GetTrigger(this.input_donl_) == true)) then
					local ring3_code = NameEntry.ring3_list_[this.ring1_idx_][this.ring2_idx_][this.ring3_idx_]
					if(ring3_code == "back") then
						-- ＳＥ
						this:PlaySECancel()

						-- 戻る
						this.ring3_idx_ = 1
						this:SetupToRing2()
					else
						-- ＳＥ
						this:PlaySEDon()

						-- 文字決定の動き
						this.centeranim_mc_:GotoAndPlay("pos_"..this.bigplate_cursor_idx_)

						-- 文字を入れちゃう
						this.name_string_[this.bigplate_cursor_idx_] = ring3_code

						this.state_:SetState("CharDecide")
					end
				end
				-- ←
				if(Input.GetTrigger(this.input_left_) == true) then
					this.ring3_idx_ = this.ring3_idx_ - 1
					if(this.ring3_idx_ <= 0) then
						this.ring3_idx_ = #(NameEntry.ring3_list_[this.ring1_idx_][this.ring2_idx_])
					end

					this.ring3_disp_mc_.cursor_plate:SetVisible(false)
					-- アニメーション
					this.ring3_disp_mc_:GotoAndPlay("left")
					-- ＳＥ
					this:PlaySEKatsu()

					this.state_:SetState("Ring3Move")
				end
				-- →
				if(Input.GetTrigger(this.input_right_) == true) then
					this.ring3_idx_ = this.ring3_idx_ + 1
					if(this.ring3_idx_ > #(NameEntry.ring3_list_[this.ring1_idx_][this.ring2_idx_])) then
						this.ring3_idx_ = 1
					end

					this.ring3_disp_mc_.cursor_plate:SetVisible(false)
					-- アニメーション
					this.ring3_disp_mc_:GotoAndPlay("right")
					-- ＳＥ
					this:PlaySEKatsu()

					this.state_:SetState("Ring3Move")
				end
			end
			this.state_.func_["Ring3Move"] = function()
				this:SetDispCharPosRing3()
				if(this.ring3_disp_mc_:IsPlay() == false) then
					-- 表示調整
					this:SetDispCenter(3)

					this.ring3_disp_mc_.cursor_plate:SetVisible(true)

					this.state_:SetState("Ring3")
				end
			end

			this.state_.func_["CharDecide"] = function()
				if(this.centeranim_mc_:IsPlay() == false) then
					-- 名前プレートに反映
					this:SetNameBigplate()

					-- カーソル進める
					this.bigplate_cursor_idx_ = this.bigplate_cursor_idx_ + 1
					if(this.bigplate_cursor_idx_ > 5) then
						this.bigplate_cursor_idx_ = 5
						this.ring1_idx_ = #(NameEntry.ring1_list_)
					else
						this.ring1_idx_ = 1
					end

					-- リング１に戻る
					this.ring2_idx_ = 1
					this.ring3_idx_ = 1
					this:SetupToRing1()
				end
			end

			this.state_.func_["ToAccept"] = function()
				if(this.nameinput_mc_:IsPlay() == false) then
					-- リング消す
					this:SetDispRing1(false)

					-- 名前確認ウィンドウ
					this.accept_base_mc_:SetVisible(true)
					this:SetAcceptWindow(this.name_accept_cursor_)
					this.accept_base_mc_:GotoAndPlay("start")

					this.state_:SetState("ToAccept2")
				end
			end
			this.state_.func_["ToAccept2"] = function()
				if(this.accept_base_mc_:IsPlay() == false) then
					this.state_:SetState("Accept")
				end
			end
			this.state_.func_["Accept"] = function()
				if(this.wait_upload_ == true) then
					return
				end

				-- 決定
				if((Input.GetTrigger(this.input_donr_) == true) or (Input.GetTrigger(this.input_donl_) == true)) then
					-- カーソルアニメ
					this.accept_mc_.selectBorder:GotoAndPlay("decide")

					-- 点滅
					this.accept_mc_.blink_instance:GotoAndPlay("decide")

					if(this.name_accept_cursor_ == 1) then

						-- アップロード状態にする
						this.return_code_ = NameEntry.EnumReturn.kUpload

						-- ＳＥ
						this:PlaySEDon()
					else
						-- ＳＥ
						this:PlaySECancel()
					end

					this.state_:SetState("DecideWait")
					return
				end
				-- ←
				if(Input.GetTrigger(this.input_left_) == true) then
					if(this.name_accept_cursor_ == 2) then
						-- ＳＥ
						this:PlaySEKatsu()

						this.name_accept_cursor_ = 1
						this:SetAcceptWindow(this.name_accept_cursor_)
					end
					return
				end
				-- →
				if(Input.GetTrigger(this.input_right_) == true) then
					if(this.name_accept_cursor_ == 1) then
						-- ＳＥ
						this:PlaySEKatsu()

						this.name_accept_cursor_ = 2
						this:SetAcceptWindow(this.name_accept_cursor_)
					end
				end
			end
			this.state_.func_["DecideWait"] = function()
--				if(this.accept_mc_.selectBorder:IsPlay() == false) then
				if(this.accept_mc_.blink_instance:IsPlay() == false) then
					if(this.name_accept_cursor_ == 1) then
						-- 名前入れ
						this:DecideName()
						-- 名前チェック
						if(PlayDataManager.CheckNGName((this.playerId_ - 1)) == false) then
							-- ＳＥ
--							this:PlaySECancel()

							-- 名前確認ウィンドウは消す
							this.accept_base_mc_:SetVisible(false)

							-- ＮＧ開始
							this.ng_mc_:SetVisible(true)
							this.ng_mc_:GotoAndPlay("start")

							-- 名前を空白に
							this.bigplate_cursor_idx_ = 1
							this.name_string_ = {" "," "," "," "," "}
							this:SetNameBigplate()

							this.state_:SetState("NGName")
						else
							-- サーバーへアップロードする
							NetAccess.ResetNetAccessStatus()
							NetAccess.StartMydonEntry((this.playerId_ - 1))

							NetAccessWindow.StartLoading("now_connectserver")

							this.state_:SetState("Upload")
						end
					else
						-- 名前戻し
						if(this.name_decide_blank_ == true) then
							this.bigplate_cursor_idx_ = 1

							this.name_string_ = {" "," "," "," "," "}
							this:SetNameBigplate()
						end

						-- リング１へ戻る
						this.ring1_idx_ = 1
						this:SetupToRing1()
					end
				end
			end
			this.state_.func_["NGName"] = function()
				if(this.ng_mc_:IsPlay() == false) then
					-- 処理再開
					this.return_code_ = NameEntry.EnumReturn.kDoing

					-- リング１へ戻る
					this.ring1_idx_ = 1
					this:SetupToRing1()
				end
			end
			this.state_.func_["Upload"] = function()
				-- 一人ずつブロックするのでOK
				local ret_netaccess = NetAccess.GetNetAccessStatus()
				if(ret_netaccess == GameConnectStatus.kSuccess) then
					-- プレイヤーデータの取得を開始する
					-- メモ：３代目は裏解放情報などの初期状態がmydonentryだけで決まらないので一度サーバーからもらう
					-- 取得開始のリクエストを出す→後で取得される
					PlayDataManager.UserDataRequestRequestWait((this.playerId_ - 1))

					NetAccessWindow.Close()

					this.state_:SetState("ToSuccess")
				end
				if(ret_netaccess == GameConnectStatus.kError) then
					NetAccessWindow.Close()

					this.state_:SetState("ToError")
				end
			end
			this.state_.func_["ToSuccess"] = function()
				if(NetAccessWindow.IsPlay() == false) then
					NetAccessWindow.StartSuccess("connectserver_ok","connectserver_nameok_sub")
					-- ＳＥ「バナパスポート読み込み成功」
					TSound:Play("se_common_v12a","card_success")
					this.state_:SetState("Success")
				end
			end
			this.state_.func_["Success"] = function()
				if(this.state_.count_ > (Common.FPS * 3)) then
					NetAccessWindow.Close()
					this.state_:SetState("SuccessToEnd")
				end
			end
			this.state_.func_["SuccessToEnd"] = function()
				if(NetAccessWindow.IsPlay() == false) then
					NetAccessWindow.CloseAll()
					this.state_:SetState("EndWait")
				end
			end

			this.state_.func_["ToError"] = function()
				if(NetAccessWindow.IsPlay() == false) then
					NetAccessWindow.StartError("connectserver_error","connectserver_nameng_sub")
					-- ＳＥ「バナパスポート読み込み失敗」
					TSound:Play("se_common_v12a","card_error")
					this.state_:SetState("Error")
				end
			end
			this.state_.func_["Error"] = function()
				if(this.state_.count_ > (Common.FPS * 3)) then
					NetAccessWindow.Close()

					-- コインプレイにする
					PlayDataManager.ChangeToCoinUser((this.playerId_ - 1))
					this.state_:SetState("ErrorToEnd")
				end
			end
			this.state_.func_["ErrorToEnd"] = function()
				if(NetAccessWindow.IsPlay() == false) then
					NetAccessWindow.CloseAll()
					this.state_:SetState("EndWait")
				end
			end

			this.state_.func_["EndWait"] = function()
				if(NetAccessWindow.IsPlayAll() == false) then
					this:SetFinish()

					-- 消す
					this.mc_:GotoAndPlay("fade_out")

					this.state_:SetState("End")
				end
			end
			this.state_.func_["End"] = function()
			end

		end,

		-- 名前プレートのカーソルを設定する
		SetBigplateCursor = function(this,pos)
			for loop_idx = 1,5 do
				if(loop_idx == pos) then
					this.dispname_char_mc_[loop_idx].cursor_frame:SetVisible(true)
					this.dispname_char_mc_[loop_idx].cursor_plate:SetVisible(true)
				else
					this.dispname_char_mc_[loop_idx].cursor_frame:SetVisible(false)
					this.dispname_char_mc_[loop_idx].cursor_plate:SetVisible(false)
				end
			end
		end,
		-- 名前プレートの文字を設定する
		SetNameBigplate = function(this)
			for loop_idx = 1,5 do
				this:SetNameCharBigplate(loop_idx,this.name_string_[loop_idx])
			end
		end,
		SetNameCharBigplate = function(this,pos,char)
			if(char == " ") then
				this.dispname_char_mc_[pos].moji:SetVisible(false)
			else
				this.dispname_char_mc_[pos].moji:SetVisible(true)
				this.dispname_char_mc_[pos].moji:GotoAndStop(char)
			end
		end,

		-- リングの状態を設定する
		SetupToRing1 = function(this)
			-- 名前確認ウィンドウは消す
			this.accept_base_mc_:SetVisible(false)

			-- 操作ガイド出す
			this.guide_mc_:SetVisible(true)

			-- 名前プレートのカーソル戻す
			this:SetBigplateCursor(this.bigplate_cursor_idx_)

			-- リングのカーソル消す
			this:SetRingCursor(false)

			-- リング１状態
			this:SetDispModeRing1()

			-- アニメーション
			this.nameinput_mc_:GotoAndPlay("ring1")

			this.state_:SetState("ToRing1")
		end,
		SetupToRing2 = function(this)
			-- リングのカーソル消す
			this:SetRingCursor(false)

			-- リング２状態
			this:SetDispModeRing2()

			-- アニメーション
			this.nameinput_mc_:GotoAndPlay("ring2")

			this.state_:SetState("ToRing2")
		end,
		SetupToRing3 = function(this)
			-- リングのカーソル消す
			this:SetRingCursor(false)

			-- リング３状態
			this:SetDispModeRing3()

			-- アニメーション
			this.nameinput_mc_:GotoAndPlay("ring3")

			this.state_:SetState("ToRing3")
		end,

		SetupToAccept = function(this)
			this.name_accept_cursor_ = 2

			-- 名前プレートのカーソル消す
			this:SetBigplateCursor(-1)
			-- リング消す
			this:SetRingCursor(false)
--			this:SetDispRing1(false)
			this:SetDispRing2(false)
			this:SetDispRing3(false)

			-- アニメーション
			this.nameinput_mc_:GotoAndPlay("ring2")

			-- 中央消す
			this:SetDispCenter(-1)

			-- 操作ガイド消す
			this.guide_mc_:SetVisible(false)

			this.state_:SetState("ToAccept")
		end,

		-- リングのカーソル
		SetRingCursor = function(this,flag)
			this.nameinput_mc_.cursor_frame:SetVisible(flag)
			this.nameinput_mc_.cursor:SetVisible(flag)
		end,

		-- 状態に合わせたリングの表示設定
		SetDispModeRing1 = function(this)
			this:SetDispCenter(1)

			this:SetDispRing1(true)
			this:SetDispRing2(true)
			this:SetDispRing3(false)

			this.ring2_4_mc_.cursor_plate:SetVisible(false)
			this.ring2_5_mc_.cursor_plate:SetVisible(false)
			this.ring2_6_mc_.cursor_plate:SetVisible(false)
		end,
		SetDispModeRing2 = function(this)
			this:SetDispCenter(2)

			this:SetDispRing1(false)
			this:SetDispRing2(true)
			this:SetDispRing3(true)

			this.ring2_4_mc_.cursor_plate:SetVisible(true)
			this.ring2_5_mc_.cursor_plate:SetVisible(true)
			this.ring2_6_mc_.cursor_plate:SetVisible(true)

			this.ring3_3_mc_.cursor_plate:SetVisible(false)
			this.ring3_4_mc_.cursor_plate:SetVisible(false)
		end,
		SetDispModeRing3 = function(this)
			this:SetDispCenter(3)

			this:SetDispRing1(false)
			this:SetDispRing2(false)
			this:SetDispRing3(true)

			this.ring3_3_mc_.cursor_plate:SetVisible(true)
			this.ring3_4_mc_.cursor_plate:SetVisible(true)
		end,

		-- リングの表示状態調整
		SetDispRing1 = function(this,flag)
			this.ring1_mc_:SetVisible(flag)
			if(flag == true) then
				this:SetDispCharPosRing1()
			end
		end,
		SetDispRing2 = function(this,flag)
			this.ring2_mc_:SetVisible(flag)
			if(flag == true) then
				-- １段目の状態で表示物を変える
				local ring1_param = NameEntry.ring1_list_[this.ring1_idx_]
				if(ring1_param[2] == 4) then
					-- 「や行」は４枠（やゆよ＋もどる）
					this.ring2_4_mc_:SetVisible(true)
					this.ring2_5_mc_:SetVisible(false)
					this.ring2_6_mc_:SetVisible(false)

					this.ring2_disp_mc_ = this.ring2_4_mc_
				elseif(ring1_param[2] == 5) then
					-- 「特殊」は５枠（～－！？＋もどる）
					this.ring2_4_mc_:SetVisible(false)
					this.ring2_5_mc_:SetVisible(true)
					this.ring2_6_mc_:SetVisible(false)

					this.ring2_disp_mc_ = this.ring2_5_mc_
				elseif(ring1_param[2] == 0) then
					-- 「もどる」「おわり」はなし
					this.ring2_4_mc_:SetVisible(false)
					this.ring2_5_mc_:SetVisible(false)
					this.ring2_6_mc_:SetVisible(false)
				else
					-- それ以外は６枠（母音５音＋もどる）
					this.ring2_4_mc_:SetVisible(false)
					this.ring2_5_mc_:SetVisible(false)
					this.ring2_6_mc_:SetVisible(true)

					this.ring2_disp_mc_ = this.ring2_6_mc_

					this:SetDispRingChar(this.ring2_6_mc_,ring1_param[1],{"a","k","s","t","n","h","m","r","w"},{"1_ins","2_ins","3_ins","4_ins","5_ins"})
				end
				this:SetDispCharPosRing2()
			end
		end,
		SetDispRing3 = function(this,flag)
			this.ring3_mc_:SetVisible(flag)
			if(flag == true) then
				-- ２段目の状態で表示物を変える
				local ring2_param = NameEntry.ring2_list_[this.ring1_idx_][this.ring2_idx_]
				if(ring2_param[2] == 3) then
					-- 「あいうえおかきくけこさしすせそたちてとやゆよわ」は３枠
					this.ring3_3_mc_:SetVisible(true)
					this.ring3_4_mc_:SetVisible(false)

					this.ring3_disp_mc_ = this.ring3_3_mc_

					this:SetDispRingChar(this.ring3_3_mc_,ring2_param[1],{"a","i","u","e","o","ka","ki","ku","ke","ko","sa","si","su","se","so","ta","ti","te","to","ya","yu","yo","wa"},{"1_ins","2_ins"})
				elseif(ring2_param[2] == 4) then
					-- 「つはひふへほ」は４枠
					this.ring3_3_mc_:SetVisible(false)
					this.ring3_4_mc_:SetVisible(true)

					this.ring3_disp_mc_ = this.ring3_4_mc_

					this:SetDispRingChar(this.ring3_4_mc_,ring2_param[1],{"tu","ha","hi","hu","he","ho"},{"1_ins","2_ins","3_ins"})
				else
					-- それ以外はなし
					this.ring3_3_mc_:SetVisible(false)
					this.ring3_4_mc_:SetVisible(false)
				end
				this:SetDispCharPosRing3()
			end
		end,

		SetDispRingChar = function(this,targetMc,targetCode,insname_pre,insname_post)
			for loop_idx = 1,#insname_pre do
				for loop_idx2 = 1,#insname_post do
					local ins_name = insname_pre[loop_idx]..insname_post[loop_idx2]

					if(targetCode == insname_pre[loop_idx]) then
						targetMc[ins_name]:SetVisible(true)
					else
						targetMc[ins_name]:SetVisible(false)
					end
				end
			end
		end,

		SetDispCenter = function(this,ringid)
			local ring_param = nil

			if(ringid == 1) then
				ring_param = NameEntry.ring1_list_[this.ring1_idx_]
			elseif(ringid == 2) then
				ring_param = NameEntry.ring2_list_[this.ring1_idx_][this.ring2_idx_]
			elseif(ringid == 3) then
				ring_param = {}
				ring_param[1] = NameEntry.ring3_list_[this.ring1_idx_][this.ring2_idx_][this.ring3_idx_]
				ring_param[2] = 0
			end

			if(ring_param ~= nil) then
				this.centeranim_mc_:SetVisible(true)
				this.centeranim_mc_:GotoAndStop("head_1")

				if(ring_param[2] == 0) then
					this.centeranim_mc_.plate.cursor_plate:SetVisible(true)
					this.centeranim_mc_.plate.moji:SetVisible(true)
					this.centeranim_mc_.plate.moji:GotoAndStop(ring_param[1])
				else
					this.centeranim_mc_.plate.cursor_plate:SetVisible(false)
					this.centeranim_mc_.plate.moji:SetVisible(false)
				end
			else
				this.centeranim_mc_:SetVisible(false)
			end
		end,

		-- 文字の表示位置調整関連
		SetDispCharPosRing1 = function(this)
			-- リング１の選択位置表示調整
			for loop_idx = 1,#(NameEntry.ring1_list_) do
				local plate_mc_name = "plate_"..loop_idx
				local moji_idx = (loop_idx + this.ring1_idx_ - 2) % #(NameEntry.ring1_list_) + 1
				local moji_mc_name = "moji_"..moji_idx

				this.ring1_mc_[moji_mc_name].x = this.ring1_mc_[plate_mc_name].x
				this.ring1_mc_[moji_mc_name].y = this.ring1_mc_[plate_mc_name].y
			end
		end,
		SetDispCharPosRing2 = function(this)
			-- リング２の選択位置表示調整
			local ring1_param = NameEntry.ring1_list_[this.ring1_idx_]
			if(ring1_param[2] ~= 0) then
				local ring2_param = NameEntry.ring2_list_[this.ring1_idx_][this.ring2_idx_]

				for loop_idx = 1,ring1_param[2] do
					local plate_mc_name = "plate_"..loop_idx

					local moji_idx = (loop_idx + this.ring2_idx_ - 2) % ring1_param[2] + 1
					local moji_mc_name = "moji_"..moji_idx

					-- 何パターンもあるのは個別
					if((moji_idx ~= ring1_param[2]) and (ring1_param[2] == 6)) then
						moji_mc_name = ring1_param[1]..moji_idx.."_ins"
					end

					this.ring2_disp_mc_[moji_mc_name].x = this.ring2_disp_mc_[plate_mc_name].x
					this.ring2_disp_mc_[moji_mc_name].y = this.ring2_disp_mc_[plate_mc_name].y
				end
			end
		end,
		SetDispCharPosRing3 = function(this)
			-- リング３の選択位置表示調整
			local ring2_param = NameEntry.ring2_list_[this.ring1_idx_][this.ring2_idx_]
			if(ring2_param[2] ~= 0) then

				for loop_idx = 1,ring2_param[2] do
					local plate_mc_name = "plate_"..loop_idx

					local moji_idx = (loop_idx + this.ring3_idx_ - 2) % ring2_param[2] + 1
					local moji_mc_name = "moji_"..moji_idx

					-- もどる以外は個別
					if(moji_idx ~= ring2_param[2]) then
						moji_mc_name = ring2_param[1]..moji_idx.."_ins"
					end

					this.ring3_disp_mc_[moji_mc_name].x = this.ring3_disp_mc_[plate_mc_name].x
					this.ring3_disp_mc_[moji_mc_name].y = this.ring3_disp_mc_[plate_mc_name].y
				end
			end
		end,

		-- 確認ウィンドウ
		SetAcceptWindow = function(this,cursor)
			if(cursor == 1) then
				this.accept_mc_:GotoAndStop("yes")
				this.accept_mc_.button_no_instance:GotoAndStop("color_2p")
				this.accept_mc_.button_yes_instance:GotoAndStop("color_1p")
			else
				this.accept_mc_:GotoAndStop("no")
				this.accept_mc_.button_no_instance:GotoAndStop("color_1p")
				this.accept_mc_.button_yes_instance:GotoAndStop("color_2p")
			end
		end,

		-- ＳＥ関連
		PlaySEDon = function(this)
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
		end,
		PlaySEKatsu = function(this)
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
		end,
		PlaySECancel = function(this)
			if(this.player_num_ == 1) then
				-- ＳＥ「キャンセル（中央）」
				TSound:Play("se_common_v12a","primal_cancel_c")
			else
				if(this.playerId_ == 1) then
					-- ＳＥ「キャンセル（左）」
					TSound:Play("se_common_v12a","primal_cancel_l")
				else
					-- ＳＥ「キャンセル（右）」
					TSound:Play("se_common_v12a","primal_cancel_r")
				end
			end
		end,

		-- 名前を決定する→C側に
		DecideName = function(this)
			PlayDataManager.SetRomanName((this.playerId_ - 1),this.name_string_)
		end,

		-- タイムアップ時の処理
		TimeUp = function(this)
			-- 空欄は名前を強制設定
			this:ChangeBlankNameToDefaultName()

			-- この時点での名前入れ
			this:DecideName()
			-- 名前チェック
			if(PlayDataManager.CheckNGName((this.playerId_ - 1)) == false) then
				-- NG名はデフォルト名にする
				this:SetDefaultName()
				this:SetNameBigplate()
				-- 名前入れ
				this:DecideName()
			end

			-- サーバーへアップロードする
			NetAccess.ResetNetAccessStatus()
			NetAccess.StartMydonEntry((this.playerId_ - 1))

			NetAccessWindow.StartLoading("now_connectserver")

			this.return_code_ = NameEntry.EnumReturn.kUpload

			this.state_:SetState("Upload")
		end,

		-- 空欄名のチェック
		ChangeBlankNameToDefaultName = function(this)
			if( (this.name_string_[1] == " ") and
				(this.name_string_[2] == " ") and
				(this.name_string_[3] == " ") and
				(this.name_string_[4] == " ") and
				(this.name_string_[5] == " ")) then
				this:SetDefaultName()
				this:SetNameBigplate()
				this.name_decide_blank_ = true
			else
				this.name_decide_blank_ = false
			end
		end,
		-- デフォルト名設定
		SetDefaultName = function(this)
			this.name_string_ = {"do","nn","ti","xya","nn"}
		end
	}
end

