-- バナパス受付
require("common.State")
require("common.Sound")

QRLoad = {
	Init = function(this)
		this.state_ = State.New("QRLoad")
		this.result_ = 0
		this.result_reserve_ = 0
		this.error_code_ = CardTouchError.kNone
		this.scene_ = SceneType.kNone
		this.check_id_ = 0
	end,
	-- 初期化
	Setup = function(this)
		-- ステートマシン組み立てる
		this.state_.func_["Begin"] = function()
			-- 自動で開始しない
		end
		this.state_.func_["QRTouchWait"] = function()
			local qr_status = QR.GetQRTouchStatus()
			if((qr_status ~= GameConnectStatus.kNone) and (qr_status ~= GameConnectStatus.kWait)) then
				-- 読み込み中表示にする
				QRAccessWindow.StartLoading("now_connectserver_qr")

				-- ＳＥ消す
				TSound:StopSlot(kEntrySoundSlot_CautionVoice0)

				-- ＳＥ「バナパスポート読み込み中」
--				TSound:PlaySlot("se_common_v12a","card_reading_loop",kEntrySoundSlot_CautionVoice1)

				-- 処理中に
				this.result_ = 1

				this.state_:SetState("ToReading")
			end
		end
		this.state_.func_["ToReading"] = function()
			if(QRAccessWindow.IsPlay() == false) then
				this.state_:SetState("QRReading")
			end
		end
		this.state_.func_["QRReading"] = function()
			local qr_status = QR.GetQRTouchStatus()
			if((qr_status == GameConnectStatus.kSuccess) or (qr_status == GameConnectStatus.kError)) then
				if(qr_status == GameConnectStatus.kSuccess) then
					-- 成功しているのでサーバーへリクエストを投げる
					-- まずは１Ｐ
					this.check_id_ = 0
					this.state_:SetState("StartQRVerify")
				else
					-- 失敗の理由を取得
					this.error_code_ = QR.GetQRTouchResult(0)

					-- 読み込み中を閉じる
					QRAccessWindow.Close()
					TSound:StopSlot(kEntrySoundSlot_CautionVoice1)
					this.state_:SetState("ToError")
				end
			end
		end

		this.state_.func_["StartQRVerify"] = function()
			NetAccess.StartQRCheck(this.check_id_)
			this.state_:SetState("WaitNetAccess")
		end

		this.state_.func_["WaitNetAccess"] = function()
			local ret_netaccess = NetAccess.GetNetAccessStatus()
			if(ret_netaccess == GameConnectStatus.kSuccess) then
				local card_data = PlayDataManager.GetCardReadData()

				-- 1P側チェック後
				local is_finish = false
				if(this.check_id_ == 0) then
					-- ２Ｐチェックが不要なパターン
					-- １Ｐも２Ｐも不参加の場合は１回で良い
					if((PlayDataManager.GetUserType(0) == UserType.kNone) and (PlayDataManager.GetUserType(1) == UserType.kNone)) then
						is_finish = true
						-- １Ｐだけで終わる場合、２Ｐ側のエラーは１Ｐ側と同じ
						QR.CopyResult1Pto2P()
					end
				else
					is_finish = true
				end

				if(is_finish == false) then
					-- ネットワークアクセス状態クリア
					NetAccess.ResetNetAccessStatus()
					-- ２Ｐ側のチェック開始
					this.check_id_ = 1
					this.state_:SetState("StartQRVerify")
				else
					-- 結果を取得して分岐
					local result_1p = QR.GetQRTouchResult(0)
					local result_2p = QR.GetQRTouchResult(1)

					local is_present_qr = false

					-- どちらかが成功したら成功としたい
					if((result_1p == CardTouchError.kNone) or (result_2p == CardTouchError.kNone)) then
						local work_result = CardTouchError.kNone

						-- 読み込んだコードの使用条件チェック
						if(card_data.qr_data.qrDataList_size > 0) then
							local qrCodeInfo = QRCodeInfo.create(card_data.qr_data.qrDataList[1].responseId)
							-- このシーン（画面）で使えるかチェック
							if(qrCodeInfo.useScene[(this.scene_ + 1)] == false) then
								-- 「使えない画面」エラー
								work_result = CardTouchError.kUseSceneNG

								-- モードとしても使えない場合は「使えないモード」エラー
								if(this.scene_ == SceneType.kSongSelect) then
									if(qrCodeInfo.availableMode[(GameMode.kEnso + 1)] == false) then
										work_result = CardTouchError.kModeNG
									end
								end
								if(this.scene_ == SceneType.kDaniSelect) then
									if(qrCodeInfo.availableMode[(GameMode.kDani + 1)] == false) then
										work_result = CardTouchError.kModeNG
									end
								end
								if(this.scene_ == SceneType.kAISelect) then
									if(qrCodeInfo.availableMode[(GameMode.kAI + 1)] == false) then
										work_result = CardTouchError.kModeNG
									end
								end

							elseif(qrCodeInfo.singleOnly == true) then
							-- 二人で使えるかチェック
								local credit_entry_num = PlayDataManager.GetUseCreditEntryUserCount()
								if(credit_entry_num >= 2) then
								-- クレジット済みエントリーが二人
									-- 一人でしか使えない
									work_result = CardTouchError.kSingleOnly
								elseif(credit_entry_num >= 1) then
								-- クレジット済みエントリーが一人→一人は参加確定している。
									-- 失敗している側（ここではどちらかのみ）
									local fail_player = 0
									local work_error = CardTouchError.kNone
									if(result_1p ~= CardTouchError.kNone) then
										fail_player = 1
										work_error = result_1p
									end
									if(result_2p ~= CardTouchError.kNone) then
										fail_player = 2
										work_error = result_2p
									end
									if(fail_player ~= 0) then
										-- 失敗しているプレイヤーがクレジット済みだったら
										if(PlayDataManager.GetUseCreditFlag((fail_player - 1)) == true) then
											-- 失敗へ
											work_result = CardTouchError.kSingleOnly
										end
									end
								end
							end

							if(qrCodeInfo.qrType == QRCodeType.kPresentQR) then
								is_present_qr = true
							end

							if(qrCodeInfo.qrType == QRCodeType.kSongSelect) then
								-- カード読み込み領域から選曲IDを取得
								local musicId = QR.GetSongSelectMusicIDFromTouchData()
								if(musicId <= 0) then
									-- 曲が選べないエラー
									work_result = CardTouchError.kSongNG
								end
							end

							if(qrCodeInfo.qrType == QRCodeType.kCustomFolder) then
								-- カスタムフォルダの中の曲が一つも選べない
								if(QR.CheckEnableCustomFolderSongsTouchData() == false) then
									-- 遊べる曲がないエラー
									work_result = CardTouchError.kSongInFolderNG
								end
							end
						else
							-- その他の失敗へ
							work_result = CardTouchError.kCardError
						end

						-- 成功した側を上書き
						if(result_1p == CardTouchError.kNone) then
							result_1p = work_result
						end
						if(result_2p == CardTouchError.kNone) then
							result_2p = work_result
						end
					end

					-- 結果コードはより小さい方を使う、成功は0なので成功を含む場合は成功になる
					if(result_1p <= result_2p) then
						this.error_code_ = result_1p
					else
						this.error_code_ = result_2p
					end

					if(this.error_code_ == CardTouchError.kNone) then
						if(is_present_qr == true) then
							-- ネットワークアクセス状態クリア
							NetAccess.ResetNetAccessStatus()
							-- プレゼント用ＱＲコードの確認へ
							this.check_id_ = 0
							this.state_:SetState("StartGetURL")
						else
							-- 成功へ
							this.state_:SetState("ToSuccess")
							-- 読み込み中を閉じる
							QRAccessWindow.Close()
							TSound:StopSlot(kEntrySoundSlot_CautionVoice1)
						end
					else
						-- 失敗へ
						this.state_:SetState("ToError")
						-- 読み込み中を閉じる
						QRAccessWindow.Close()
						TSound:StopSlot(kEntrySoundSlot_CautionVoice1)
					end
				end
			end
			if(ret_netaccess == GameConnectStatus.kError) then
				-- その他の失敗へ
				this.error_code_ = QR.GetQRTouchResult(this.check_id_)
				this.state_:SetState("ToError")
			end
		end

		this.state_.func_["StartGetURL"] = function()
			NetAccess.StartGetURL(this.check_id_)
			this.state_:SetState("WaitGetURL")
		end
		this.state_.func_["WaitGetURL"] = function()
			local ret_netaccess = NetAccess.GetNetAccessStatus()
			if(ret_netaccess == GameConnectStatus.kSuccess) then
				if(this.check_id_ == 0) then
					-- ネットワークアクセス状態クリア
					NetAccess.ResetNetAccessStatus()
					-- ２Ｐ側のチェック開始
					this.check_id_ = 1
					this.state_:SetState("StartGetURL")
				else
					-- 成功へ
					this.state_:SetState("ToSuccess")
					-- 読み込み中を閉じる
					QRAccessWindow.Close()
					TSound:StopSlot(kEntrySoundSlot_CautionVoice1)
				end
			end
			if(ret_netaccess == GameConnectStatus.kError) then
				-- その他の失敗へ
				this.error_code_ = QR.GetQRTouchResult(this.check_id_)
				this.state_:SetState("ToError")
			end
		end

		this.state_.func_["ToSuccess"] = function()
			if(QRAccessWindow.IsPlay() == false) then
				-- デフォルト
				local key_title = "connectserver_qr_ok"
				local key_sub = "connectserver_qr_ok_sub"

--[[
-- 2020.06.18 ＱＲの種類で表示変えるのをやめる。
				-- ＱＲの種類で表示を変える
				local card_data = PlayDataManager.GetCardReadData()
				if(card_data.qr_data.qrDataList_size > 0) then
					local qrCodeInfo = QRCodeInfo.create(card_data.qr_data.qrDataList[1].responseId)

					-- 「選曲」
					if(qrCodeInfo.qrType == QRCodeType.kSongSelect) then
						key_sub = "qrcode_songselect_sub"
					end
					-- 「友達ＡＩ」
					if(qrCodeInfo.qrType == QRCodeType.kFriendAI) then
						key_sub = "qrcode_friendai_sub"
					end
					-- 「コラボキャラＡＩ」
					if(qrCodeInfo.qrType == QRCodeType.kCollaboAI) then
						key_sub = "qrcode_collaboai_sub"
					end
					-- 「お題」
					if(qrCodeInfo.qrType == QRCodeType.kOriginalOdai) then
						key_sub = "qrcode_originalodai_sub"
					end
					-- 「コラボイベント」
					if(qrCodeInfo.qrType == QRCodeType.kCollaboEvent) then
						key_sub = "qrcode_collaboevent_sub"
					end
				end
]]

				QRAccessWindow.StartSuccess(key_title,key_sub)

				-- ＳＥ「バナパスポート読み込み成功」
				TSound:Play("se_common_v12a","card_success")

				this.state_:SetState("Success")
			end
		end
		this.state_.func_["Success"] = function()
			if(this.state_.count_ > (Common.FPS * 2.0)) then
				QRAccessWindow.Close()
				this.state_:SetState("SuccessToEnd")
			end
		end
		this.state_.func_["SuccessToEnd"] = function()
			if(QRAccessWindow.IsPlay() == false) then
				QRAccessWindow.CloseAll()
				this.result_reserve_ = 2
				this.state_:SetState("EndWait")
			end
		end

		this.state_.func_["ToError"] = function()
			if(QRAccessWindow.IsPlay() == false) then
				-- デフォルト「通信に失敗しました」
				local key_title = "connectserver_error"
				local key_sub = "connectserver_qr_error_sub"

				-- エラーの種類で表示を変える
				-- 「お問い合わせください」
				if(this.error_code_ == CardTouchError.kDataFail) then
					key_title = "qrcode_available_error"
					key_sub = "qrcode_cantuse_sub"
				end
				-- 「使用期間外です」
				if(this.error_code_ == CardTouchError.kOutOfTerm) then
					key_title = "qrcode_available_error"
					key_sub = "qrcode_outofterm_sub"
				end
				-- 「カード専用」
				if(this.error_code_ == CardTouchError.kCardOnly) then
					key_title = "qrcode_available_error"
					key_sub = "qrcode_cardonly_sub"
				end
				-- 「非カード専用」
				if(this.error_code_ == CardTouchError.kNoCardOnly) then
					key_title = "qrcode_available_error"
					key_sub = "qrcode_nocardonly_sub"
				end
				-- 「利用人数オーバー」
				if(this.error_code_ == CardTouchError.kOverUserCount) then
					key_title = "qrcode_available_error"
					key_sub = "qrcode_overusercount_sub"
				end
				-- 「使用回数オーバー」
				if(this.error_code_ == CardTouchError.kOverTime) then
					key_title = "qrcode_available_error"
					key_sub = "qrcode_overtime_sub"
				end
				-- 「このお店では使用できません」
				if(this.error_code_ == CardTouchError.kCaseShopNG) then
					key_title = "qrcode_available_error"
					key_sub = "qrcode_caseng_sub"
				end
				-- 「この画面では使用できません」
				if(this.error_code_ == CardTouchError.kUseSceneNG) then
					key_title = "qrcode_available_error"
					if(this.scene_ == SceneType.kEntry) then
						-- 「モードを選択してから」表示
						key_sub = "qrcode_nomodeselect_sub"
					else
						key_sub = "qrcode_sceneng_sub"
					end
				end
				-- 「このモードでは使用できません」
				if(this.error_code_ == CardTouchError.kModeNG) then
					key_title = "qrcode_available_error"
					if(this.scene_ == SceneType.kEntry) then
						-- 「モードを選択してから」表示
						key_sub = "qrcode_nomodeselect_sub"
					else
						key_sub = "qrcode_modeng_sub"
					end
				end
				-- 「ふたりで使えない」
				if(this.error_code_ == CardTouchError.kSingleOnly) then
					key_title = "qrcode_available_error"
					key_sub = "qrcode_singleonly_sub"
				end
				-- 「すでに読み込んでる」
				if(this.error_code_ == CardTouchError.kSameQR) then
					key_title = "qrcode_available_error"
					key_sub = "qrcode_samedata_sub"
				end
				-- 「すでに持っている（報酬獲得済み）」
				if(this.error_code_ == CardTouchError.kItemHave) then
					key_title = "qrcode_available_error"
					key_sub = "qrcode_haveitem_sub"
				end
				-- 「ＵＲＬの取得に失敗」
				if(this.error_code_ == CardTouchError.kURLNG) then
					key_title = "qrcode_available_error"
					key_sub = "qrcode_cantuse_sub"
				end
				-- 「遊べない曲だった」
				if(this.error_code_ == CardTouchError.kSongNG) then
					key_title = "qrcode_available_error"
					key_sub = "qrcode_songng_sub"
				end
				-- 「フォルダの曲が全て遊べない曲だった」
				if(this.error_code_ == CardTouchError.kSongInFolderNG) then
					key_title = "qrcode_available_error"
					key_sub = "qrcode_songinfolderng_sub"
				end

				-- 「読み込みに失敗しました」
				if(this.error_code_ == CardTouchError.kCardError) then
					key_title = "card_read_error"
					key_sub = ""
				end
				-- 「閉店処理時間」
				if(this.error_code_ == CardTouchError.kClosing) then
					key_sub = "qrcode_closing_sub"
				end
				-- 「閉店中」
				if(this.error_code_ == CardTouchError.kClosed) then
					key_sub = "qrcode_closed_sub"
				end
				-- 「メンテナンス前」
				if(this.error_code_ == CardTouchError.kBeforeMaintenance) then
					key_sub = "qrcode_beforemaintenance_sub"
				end
				-- 「メンテナンス中」
				if(this.error_code_ == CardTouchError.kUnderMaintenance) then
					key_sub = "qrcode_undermaintenance_sub"
				end
				-- 「メンテナンス中」
				if(this.error_code_ == CardTouchError.kUnderMaintenance) then
					key_sub = "qrcode_undermaintenance_sub"
				end

				QRAccessWindow.StartError(key_title,key_sub)
				-- ＳＥ「バナパスポート読み込み失敗」
				TSound:Play("se_common_v12a","card_error")

				this.state_:SetState("Error")
			end
		end
		this.state_.func_["Error"] = function()
			if(this.state_.count_ > (Common.FPS * 2.0)) then
				QRAccessWindow.Close()
				this.state_:SetState("ErrorToEnd")
			end
		end
		this.state_.func_["ErrorToEnd"] = function()
			if(QRAccessWindow.IsPlay() == false) then
				QRAccessWindow.CloseAll()
				this.result_reserve_ = -1
				this.state_:SetState("EndWait")
			end
		end

		this.state_.func_["EndWait"] = function()
			if(QRAccessWindow.IsPlayAll() == false) then
				this.result_ = this.result_reserve_

				-- 処理が終わった
				this.state_:SetState("End")
			end
		end
		this.state_.func_["End"] = function()
		end
	end,
	-- 開始
	TouchWaitStart = function(this,resetFlag,scene)
		QRAccessWindow.Wait()

		this.state_:SetState("QRTouchWait")
		this.result_ = 0
		this.scene_ = scene

		-- カードタッチ開始
		if(resetFlag == true) then
			QR.StartQRTouch()
		end

		-- ネットワークアクセス状態クリア
		NetAccess.ResetNetAccessStatus()
	end,
	-- 終了
	TouchWaitFinish = function(this)
		QRAccessWindow.Wait()

		-- カードタッチ終了
		QR.FinishQRTouch()

		this.state_:SetState("End")

		this.result_ = 0
		this.result_reserve_ = 0
		this.scene_ = SceneType.kNone
	end,

	-- 更新
	Update = function(this)
		-- QRVerifyを回す
		NetAccess.ProcQRCheck()

		-- ステート実行
		this.state_:Update()

		-- 0:何もしてない
		-- 1:処理中
		-- 2:成功
		-- -1:エラー
		return this.result_
	end,


}
