-- 使うクラスを読み込む
require("common.ControlGuide")
require("common.CreditSide")
require("common.NamePlate")
require("common.PlayerInfo")
require("common.State")
require("common.Sound")
require("common.Timer")
require("entry.card_load")
require("entry.credit_wait")
require("entry.costume_select")
require("entry.mode_select")
require("entry.nameentry")
require("entry.qr_load")
require("entry.qr_taiko_select")
require("entry.setting_base")
require("entry.taiko_select")
require("entry.wait_don")

-- 定数類
kEntrySoundSlot_BGM0 = 0
kEntrySoundSlot_BGM1 = 1
kEntrySoundSlot_CautionVoice0 = 2
kEntrySoundSlot_CautionVoice1 = 3
kEntrySoundSlot_CautionVoice2 = 4


-- このクラス
EntryMain = {
	-- 変数
	state_ = State.New("Entry"),
	timer_ = Timer.New("timer_instance"),
	control_guide_ = ControlGuide.New("controlguide_instance"),
	name_plate_ = {NamePlate.New("nameplate_instance_1"),NamePlate.New("nameplate_instance_2")},
	credit_side_ = {CreditSide.New("credit_side_instance_1"),CreditSide.New("credit_side_instance_2")},
	player_info_ = {PlayerInfo.New("playerinfo_instance_1"),PlayerInfo.New("playerinfo_instance_2")},
	entry_count_ = 0,
	card_entry_count_ = 0,
	entry_wait_ = {0,0},
	setting_type_ = {0,0},
	setting_wait_upload_ = false,
	setting_timer_play_ = false,
	has_add_count_ = false,
	start_voice_ = false,
	start_guide_ = false,
	isplay_voice_2play_ = false,
	taiko_select_from_modeselect_ = false,
	taiko_select_cansel_ = false,
	taiko_select_mode_ = 0,
	mode_select_timeup_ = false,
	mode_select_decide_ = GameMode.kEnso,

	play_data_ = {},

	old_card_result_ = 0,
	old_qr_result_ = 0,

	work_counter_ = 0,

	user_data_request_ok_ = {false,false},

	check_qr_start_ = false,

	disp_error_count_ = 0,

	update_func_name_ = "normal",
	update_func_stand_chara_ = "none",

	old_costume_ = {{},{}},
	old_stand_fla_ = {"",""},

	Init = function(this)
		this.user_data_request_ok_[1] = false
		this.user_data_request_ok_[2] = false

		-- ステートマシンを組み立てておく

		-- =============== 各種初期化 ここから ===============
		this.state_.func_["Begin"] = function()
			-- 各種パーツ読み込み
			this.timer_:LoadMovie()
			this.control_guide_:LoadMovie()

			this.name_plate_[1]:LoadMovie()
			this.name_plate_[2]:LoadMovie()

			this.credit_side_[1]:LoadMovie()
			this.credit_side_[2]:LoadMovie()

			this.player_info_[1]:LoadMovie()
			this.player_info_[2]:LoadMovie()

			-- モード選択
			ModeSelect:Init("mode_select_instance")
			ModeSelect:LoadMovie()
			-- コスチューム選択
			CostumeSelect:Init("cosutume_select_instance")
			CostumeSelect:LoadMovie()
			-- ネームエントリー
			NameEntry:Init("nameentry_instance")
			NameEntry:LoadMovie()
			-- セッティングの地
			SettingBase:Init("setting_base_instance")
			SettingBase:LoadMovie()
			-- クレジット受付
			CreditWait:Init("entrycredit_instance")
			CreditWait:LoadMovie()
			-- バナパス読み込み
			CardLoad:Init()
			-- バナパス使用確認（太鼓選択）
			TaikoSelect:Init("taiko_select_instance")
			TaikoSelect:LoadMovie()
			-- ＱＲ読み込み
			QRLoad:Init()
			-- ＱＲ使用確認（太鼓選択）
			QRTaikoSelect:Init("qr_taiko_select_instance")
			QRTaikoSelect:LoadMovie()

			this.state_:SetState("Loading")
		end
		this.state_.func_["Loading"] = function()
			-- いろいろ読み込み待ち
			-- モード選択
			if(ModeSelect:Loading() == false) then
				return
			end
			-- バナパス使用確認
			if(TaikoSelect:Loading() == false) then
				return
			end
			-- ＱＲ使用確認
			if(QRTaikoSelect:Loading() == false) then
				return
			end
			-- プレイヤー情報
			if(this.player_info_[1]:Loading() == false) then
				return
			end
			if(this.player_info_[2]:Loading() == false) then
				return
			end
			this.state_:SetState("LoadingSub")
		end
		this.state_.func_["LoadingSub"] = function()
			if (Lumen.IsLoadMovieFinish() == true) then
				-- タイマーの準備
				this.timer_:Setup(9)
				this.timer_:SetVisible(true)
				this.timer_:SetShadow(true)
				this.timer_:SetCount(60)
				this.timer_:SoundSetting(true,true)
				-- 操作ガイドの準備
				this.control_guide_:Setup()
				this.control_guide_:SetVisible(false)
				this.start_guide_ = false
				-- ネームプレートの準備
				this.name_plate_[1]:Setup()
				this.name_plate_[1]:SetVisible(false)
				this.name_plate_[2]:Setup()
				this.name_plate_[2]:SetVisible(false)
				-- クレジット表示の準備
				this.credit_side_[1]:Setup(1)
				this.credit_side_[1]:SetVisible(false)
				this.credit_side_[2]:Setup(2)
				this.credit_side_[2]:SetVisible(false)
				-- プレイヤー情報の準備
				this.player_info_[1]:Setup()
				this.player_info_[1]:SetVisible(false)
				this.player_info_[2]:Setup()
				this.player_info_[2]:SetVisible(false)

				-- モード選択の準備
				ModeSelect:Setup()
				ModeSelect:SetVisible(false)
				-- コスチューム選択の準備
				CostumeSelect:Setup()
				CostumeSelect:SetVisible(false)
				-- ネームエントリーの準備
				NameEntry:Setup()
				NameEntry:SetVisible(false)
				-- クレジット受付の準備
				CreditWait:Setup()
				CreditWait:SetVisible(false)
				-- セッティングの地の準備
				SettingBase:Setup()
				SettingBase:SetVisible(false)
				-- バナパス読み込み
				CardLoad:Setup()
				-- バナパス使用確認の準備
				TaikoSelect:Setup()
				TaikoSelect:SetVisible(false)
				-- ＱＲ読み込み
				QRLoad:Setup()
				-- ＱＲ使用確認の準備
				QRTaikoSelect:Setup()
				QRTaikoSelect:SetVisible(false)

				-- C側に準備完了通知
				Common.LuaPrepareFinish()

				-- 背景
				this.bg_ = Lumen.GetMovieClip("entrybg_instance",true)

				-- 読み込み前データ
				for loop_idx = 1,2 do
					this.old_stand_fla_[loop_idx] = ""
					this.old_costume_[loop_idx].head = 0
					this.old_costume_[loop_idx].body = 0
					this.old_costume_[loop_idx].face = 0
					this.old_costume_[loop_idx].puchi = 0
					this.old_costume_[loop_idx].kigurumi = 0
					this.old_costume_[loop_idx].faceColor = 0
					this.old_costume_[loop_idx].bodyColor = 0
					this.old_costume_[loop_idx].legsColor = 0
				end

				-- ３Ｄどん
				this.don_ = {}
				this.don_[1] = Lumen.GetMovieClip("don_1p",true)
				this.don_[2] = Lumen.GetMovieClip("don_2p",true)
				this.don_[1]:SetVisible(false)
				this.don_[2]:SetVisible(false)

				Don.ChangeDefaultDon(0,Don.kType_Don)
				Don.CameraReverse(0,false)
				Don.ChangeDefaultDon(1,Don.kType_Katsu)
				Don.CameraReverse(1,true)

				-- 脇の立ち絵
				this.stand_chara_ = {}
				this.stand_chara_enable_ = {false,false}
				this.stand_chara_[1] = Lumen.GetMovieClip("stand_chara_instance_1",true)
				this.stand_chara_[2] = Lumen.GetMovieClip("stand_chara_instance_2",true)
				this.stand_chara_[1]:SetVisible(false)
				this.stand_chara_[2]:SetVisible(false)

				-- ダミーどんちゃん
				WaitDon:Setup(Lumen.GetMovieClip("donwait_instance",true),Lumen.GetMovieClip("donsmoke_instance",true))

				-- エントリー状態取得
				this.entry_count_ = PlayDataManager.GetEntryUserCount()
				this.card_entry_count_ = PlayDataManager.GetCardEntryUserCount()

				-- ユーザーデータ一度取得
				this.play_data_[1] = PlayDataManager.GetEntryPlayData(0)
				this.play_data_[2] = PlayDataManager.GetEntryPlayData(1)

				this.state_:SetState("FadeInWait")
			end
		end
		this.state_.func_["FadeInWait"] = function()
			if(FadeFlag == false) then
				-- ＢＧＭ「エントリー汎用」
				TSound:PlaySlot("bgm_entry_v12a","primal_loop",kEntrySoundSlot_BGM0)
				TSound:PlaySlot("bgm_entry_v12a","nameentry_loop",kEntrySoundSlot_BGM1)
				TSound:SetVolumeSlot(kEntrySoundSlot_BGM1,-90.0,0)

				this.work_counter_ = 0
				this.state_:SetState("StartBGIn")
			end
		end

		-- =============== 最初の背景入り ここから ===============
		this.state_.func_["StartBGIn"] = function()
			if(this.work_counter_ >= (Common.FPS * 0.2)) then
				-- 背景ぼやかす
				this.bg_:GotoAndPlay("start")

				-- いきなりモード選択
				if(StartModeSelect == true) then
--[[
-- ＱＲ乱入はなくなった、ので、とりあえず削除
					-- 読み込み情報にＱＲが入ってるかで分岐
					local card_data = PlayDataManager.GetCardReadData()
					if(card_data.qr_data.qrDataList_size > 0) then
						-- 情報取得しなおし
						this:SetupEntryData(true)

						Don.SetNonLoopAnimation(0,"select_loop",true)
						Don.SetNonLoopAnimation(1,"select_loop",true)
						Don.SetLoopAnimation(0,"select_loop",true)
						Don.SetLoopAnimation(1,"select_loop",true)

						-- 成功→ＱＲ使う太鼓選択へ
						this.taiko_select_mode_ = 1
						-- 太鼓選択開始
						this:TaikoSelectStart(true)
					else
						-- ユーザーが入っていない側をコインでエントリする。
						for loop_idx = 1,2 do
							if(PlayDataManager.GetUserType((loop_idx - 1)) == UserType.kNone) then
								PlayDataManager.Entry((loop_idx - 1),UserType.kCoin)
							end
						end

						-- 情報取得しなおし
						this:SetupEntryData(true)

						Don.SetNonLoopAnimation(0,"select_loop",true)
						Don.SetNonLoopAnimation(1,"select_loop",true)
						Don.SetLoopAnimation(0,"select_loop",true)
						Don.SetLoopAnimation(1,"select_loop",true)

						-- カード読み込み表示開始（待機）
						CardLoad:CardTouchWaitStart(true)
						-- ＱＲ読み込み表示開始（待機）
						QRLoad:TouchWaitStart(true,SceneType.kEntry)

						this.work_counter_ = 0
						this.state_:SetState("ModeSelectStart")
					end
]]
					-- ユーザーが入っていない側をコインでエントリする。
					for loop_idx = 1,2 do
						if(PlayDataManager.GetUserType((loop_idx - 1)) == UserType.kNone) then
							PlayDataManager.Entry((loop_idx - 1),UserType.kCoin)
						end
					end

					-- 情報取得しなおし
					this:SetupEntryData(true)

					-- どんちゃんをプレイデータ状態にする
					Don.ChangeDonForPlayData()

					-- 立ち絵の読み込みを開始する
					for loop_idx = 1,2 do
						this:LoadChangeStandChara(loop_idx)
					end

					Don.SetNonLoopAnimation(0,"select_loop",true)
					Don.SetNonLoopAnimation(1,"select_loop",true)
					Don.SetLoopAnimation(0,"select_loop",true)
					Don.SetLoopAnimation(1,"select_loop",true)

					this.work_counter_ = 0
					this.state_:SetState("StartLoadWait")
				else
					-- コインorカードorＱＲ
					-- カードタッチでここに来た場合
					local card_status = BanaPass.GetCardTouchStatus()
					local qr_status = QR.GetQRTouchStatus()
					if((card_status == GameConnectStatus.kSuccess) or (card_status == GameConnectStatus.kError)) then
						-- カード読み込み表示開始（待機）
						CardLoad:CardTouchWaitStart(false)

						-- カードユーザー処理
						this.work_counter_ = 0
						this.state_:SetState("CardReadWait")
					elseif((qr_status == GameConnectStatus.kSuccess) or (qr_status == GameConnectStatus.kError)) then
						-- ＱＲ読み込み表示開始（待機）
						QRLoad:TouchWaitStart(false,SceneType.kEntry)

						-- ＱＲ処理
						this.work_counter_ = 0
						this.state_:SetState("QRReadWait")
					else
						-- カード読み込み表示開始（待機）
						CardLoad:CardTouchWaitStart(true)
						-- ＱＲ読み込み表示開始（待機）
						QRLoad:TouchWaitStart(true,SceneType.kEntry)

						-- コインユーザー処理
						this.work_counter_ = 0
						this.state_:SetState("CreditWaitStart")
					end
				end

				-- 開始できないことにしておく
				this.start_voice_ = false
				this.start_guide_ = false
			end
		end

		-- 立ち絵の読み込み待ち
		this.state_.func_["StartLoadWait"] = function()
			if ((SettingBase:LoadingStandFla() == true) and (Lumen.IsLoadMovieFinish() == true)) then
				this.work_counter_ = 0
				this.state_:SetState("StartLoadWait2")
			end
		end
		this.state_.func_["StartLoadWait2"] = function()
			-- 立ち絵キャラ読み込み後の設定
			this:AfterLoadSetupStandChara()

			-- エントリー状態にあわせたどんちゃんとネームプレートの表示
			this:DispDonAndNamePlate()

			-- カード読み込み表示開始（待機）
			CardLoad:CardTouchWaitStart(true)
			-- ＱＲ読み込み表示開始（待機）
			QRLoad:TouchWaitStart(true,SceneType.kEntry)

			this.work_counter_ = 0
			this.state_:SetState("ModeSelectStart")
		end

		-- カードタッチ後の読み込み待ち（エントリー入って最初の待ち）
		this.state_.func_["CardReadWait"] = function()
			-- カード読み込み
			local card_result = CardLoad:Update()
			if(card_result == 2) then
				-- 成功→使う太鼓選択へ
				this.taiko_select_mode_ = 0
				-- 太鼓選択開始
				this:TaikoSelectStart(false)
			end
			if(card_result == -1) then
				-- エラー、アトラクトへ戻る
				this.state_:SetState("ReturnAttractEnd")
			end
		end
		-- ＱＲタッチ後の読み込み待ち（エントリー入って最初の待ち）
		this.state_.func_["QRReadWait"] = function()
			-- ＱＲ読み込み
			local qr_result = QRLoad:Update()
			if(qr_result == 2) then
				-- 成功→ＱＲ使う太鼓選択へ
				this.taiko_select_mode_ = 1
				-- 太鼓選択開始
				this:TaikoSelectStart(false)
			end
			if(qr_result == -1) then
				-- エラー、アトラクトへ戻る
				this.state_:SetState("ReturnAttractEnd")
			end
		end

		-- =============== バナパス使用確認（太鼓選択） ここから ===============
		this.state_.func_["CardTaikoSelectStart"] = function()
			this.taiko_select_mode_ = 0

			local waitFlaName = {"",""}
			for plIdx = 1,2 do
				local listNum = this.play_data_[plIdx].qr_data.qrDataList_size
				if(listNum > 0) then
					for loop_idx = 1,listNum do
						-- QRコード情報
						local qrCodeInfo = QRCodeInfo.create(this.play_data_[plIdx].qr_data.qrDataList[loop_idx].responseId)
						if(qrCodeInfo.taikoselect_wait_fla ~= "") then
							local isQRCostume = false
							-- きせかえお試し
							if((qrCodeInfo.costumeType ~= QRCostumeType.kNone) and (qrCodeInfo.getCostume == false)) then
								isQRCostume = true
							end
							-- きせかえ獲得だがコインユーザー
							if((qrCodeInfo.costumeType ~= QRCostumeType.kNone) and (qrCodeInfo.getCostume == true) and (this.play_data_[plIdx].user_type == UserType.kCoin)) then
								isQRCostume = true
							end

							if(isQRCostume == true) then
								waitFlaName[plIdx] = qrCodeInfo.taikoselect_wait_fla
								break
							end
						end
					end
				end
			end

			WaitDon:LoadContents(waitFlaName[1],waitFlaName[2])

			this.state_:SetState("CardTaikoSelectLoadContents")
		end
		this.state_.func_["CardTaikoSelectLoadContents"] = function()
			if(WaitDon:LoadingContents() == true) then
				-- カードの場合は常に待ちどんちゃんを使う
				-- 3Dどん消す
				for loop_idx = 1,2 do
					-- コインユーザーの3Dどんちゃんは消して
					if(this.play_data_[loop_idx].user_type == UserType.kCoin) then
						this.don_[loop_idx]:SetVisible(false)
						Don.PauseAnimation((loop_idx - 1),true)
						-- 代わりに待ちどんちゃんを出す
						WaitDon:DispOn(loop_idx,this.play_data_[loop_idx].is_use_credit)
					else
						WaitDon:DispOff(loop_idx)
					end
				end

				TaikoSelect:SetVisible(true)
				TaikoSelect:Start(this.play_data_[1].user_type,this.play_data_[2].user_type)

				-- ボイスＳＥ「つかう太鼓をえらんでね！」
				TSound:Play("voice_common_v12a","taiko_choose")

				-- 操作ガイド消す
				this.control_guide_:SetVisible(false)
				this.start_guide_ = false

				-- タイマー再設定開始
				this.timer_:SetShadow(false)
				this.timer_:SetCount(20)
				this.timer_:StartCount()

				this.taiko_select_result_ = TaikoSelect.EnumReturn.kDoing
				this.taiko_select_cansel_ = false

				this.work_counter_ = 0
				this.state_:SetState("CardTaikoSelect")
			end
		end
		this.state_.func_["CardTaikoSelect"] = function()
			local taiko_result = TaikoSelect:Update()

			if(this.taiko_select_cansel_ == false) then
				if(taiko_result == TaikoSelect.EnumReturn.kDoing) then
					if(this.timer_:IsZero() == true) then
						-- 時間切れさせる
						TaikoSelect:TimeUp()
						this.taiko_select_cansel_ = true
					end
				end
			end
			if(taiko_result == TaikoSelect.EnumReturn.kDecideWait) then
				-- カウント止めちゃう
				this.timer_:StopCount()
			end
			if((taiko_result ~= TaikoSelect.EnumReturn.kDoing) and (taiko_result ~= TaikoSelect.EnumReturn.kDecideWait)) then
				this.taiko_select_result_ = taiko_result

				-- ここで太鼓選択消す
				TaikoSelect:Finish()

				-- 
				if((this.taiko_select_result_ == TaikoSelect.EnumReturn.kDecideLeft) or (this.taiko_select_result_ == TaikoSelect.EnumReturn.kDecideRight)) then
					-- 待ちどんちゃんを表示していたら煙を出す
					WaitDon:DispSmoke(this.entry_count_,this.taiko_select_result_)
				end

				this.work_counter_ = 0
				this.state_:SetState("CardTaikoSelectCloseStart")
			end
		end
		this.state_.func_["CardTaikoSelectCloseStart"] = function()
			if(this.work_counter_ >= (Common.FPS * 0.25)) then
				TaikoSelect:SetVisible(false)

				-- どんちゃんをプレイデータ状態に
--				Don.ChangeDonForPlayData()
				-- どんちゃんを読み込む→太鼓選択で使っている側を読み込み直す
				Don.ChangeDonForPlayDataOnly((TaikoSelect.use_don_id_ - 1))

				-- 向きを合わせる
				Don.CameraReverse(0,false)
				Don.CameraReverse(1,true)

				-- 一時停止解除
				Don.PauseAnimation(0,false)
				Don.PauseAnimation(1,false)

				-- タイマーリセット
				this.timer_:SetCount(60)

				this.work_counter_ = 0
				this.state_:SetState("TaikoSelectCloseWaitDonLoad")
			end
		end
		this.state_.func_["TaikoSelectCloseWaitDonLoad"] = function()
			if(Don.IsLoadedDonAll() == true) then
				-- 読み込み終わってすぐ表示するとまだうまく表示されないので1f待ちます
				this.state_:SetState("TaikoSelectClose")
			end
		end
		this.state_.func_["TaikoSelectClose"] = function()
			-- ループモーションをデフォルトに
			Don.SetLoopAnimation(0,"select_loop",true)
			Don.SetLoopAnimation(1,"select_loop",true)

			-- 「はい」を選んだ
			if(this.taiko_select_result_ == TaikoSelect.EnumReturn.kDecideYes) then
				-- QRエントリー
				if(this.taiko_select_mode_ == 1) then
					-- 共通領域への保存
					QR.UpdateCommonQRDataFromTouchData()

					-- エントリー済みがいない場合はクレジット待ちへ
					if(this.entry_count_ == 0) then
						-- カード読み込み表示開始（待機）
						this:RestartCardReadWait()

						-- エントリー状態にあわせたどんちゃんとネームプレートの表示
						this:DispDonAndNamePlate()

						-- コインユーザー処理
						this.work_counter_ = 0
						this.state_:SetState("CreditWaitStart")
					else
					-- エントリー済みがいる場合は追加エントリー→エントリー後の処理
						-- 追加エントリー
						local entry_done = {false,false}
						for loop_idx = 1,2 do
							if(this.play_data_[loop_idx].user_type ~= UserType.kNone) then
								this:QREntry(loop_idx)
								entry_done[loop_idx] = true
							end
						end
						-- 変化したどんちゃんを読み込み直す（両方エントリーしてから実行したいので処理を分けている）
						for loop_idx = 1,2 do
							if(entry_done[loop_idx] == false) then
								this:ReloadChange3DDonOnly(loop_idx)
							end
						end

						-- カード読み込み表示開始（待機）
						this:RestartCardReadWait()

						this.state_:SetState("TaikoSelectCloseWaitSide")
					end
				else
					-- QR以外でここに来ちゃったらキャンセルにする
					this.taiko_select_result_ = TaikoSelect.EnumReturn.kCancel
				end
			end

			-- キャンセルした
			if(this.taiko_select_result_ == TaikoSelect.EnumReturn.kCancel) then
				-- 待ちどんちゃんを消す
				WaitDon:DispOff(1)
				WaitDon:DispOff(2)

				this.work_counter_ = 0
				-- モード選択からきてたので戻る
				if(this.taiko_select_from_modeselect_ == true) then

					-- カード読み込み表示開始（待機）
					this:RestartCardReadWait()

					-- エントリー状態にあわせたどんちゃんとネームプレートの表示
					this:DispDonAndNamePlate()

					this.work_counter_ = 0
					this.state_:SetState("TaikoSelectCloseToModeSelect")
				else
					-- 未消費クレジット0でエントリーも0、ＱＲが保存領域にも存在しない
					if((PlayDataManager.GetNowCoin() == 0) and (this.entry_count_ == 0) and (QR.HasCommonQRData() == false))then
						-- アトラクトへ戻る
						this.state_:SetState("ReturnAttractEnd")
					else
						-- カード読み込み表示開始（待機）
						this:RestartCardReadWait()

						-- エントリー状態にあわせたどんちゃんとネームプレートの表示
						this:DispDonAndNamePlate()

						-- コインユーザー処理
						this.work_counter_ = 0
						this.state_:SetState("CreditWaitStart")
					end
				end
			end

			-- 太鼓選んでた
			if((this.taiko_select_result_ == TaikoSelect.EnumReturn.kDecideLeft) or (this.taiko_select_result_ == TaikoSelect.EnumReturn.kDecideRight)) then
				this.work_counter_ = 0

				-- エントリー
				-- カードエントリー
				if(this.taiko_select_mode_ == 0) then
					this:Entry(this.taiko_select_result_,UserType.kCard)
				end
				-- QRエントリー
				if(this.taiko_select_mode_ == 1) then

-- QRのワード
					-- 後で反対側がエントリーしたら反映できるように曲獲得は共通領域にも入れる
					local card_data = PlayDataManager.GetCardReadData()
					if(card_data.qr_data.qrDataList_size > 0) then
						local qrCodeInfo = QRCodeInfo.create(card_data.qr_data.qrDataList[1].responseId)
						if(qrCodeInfo.unique_id ~= 0) then
							if(qrCodeInfo.qrType == QRCodeType.kSongGet) then
								-- 共通領域への保存
								QR.UpdateCommonQRDataFromTouchData()
							end
						end
					end










					this:QREntry(this.taiko_select_result_)
				end
				-- 変化したどんちゃんを読み込み直す、エントリーした側は↑のEntryで処理しているので、ここでは逆側のみ
				local rev_playerid = 1
				if(this.taiko_select_result_ == TaikoSelect.EnumReturn.kDecideLeft) then
					rev_playerid = 2
				else
					rev_playerid = 1
				end
				this:ReloadChange3DDonOnly(rev_playerid)

				-- カード読み込み表示開始（待機）
				this:RestartCardReadWait()

				this.state_:SetState("TaikoSelectCloseWaitSide")
			end
		end
		this.state_.func_["TaikoSelectCloseWaitSide"] = function()
			if ((SettingBase:LoadingStandFla() == true) and (Lumen.IsLoadMovieFinish() == true)) then
				this.work_counter_ = 0
				this.state_:SetState("TaikoSelectCloseWaitSide2")
			end
		end
		this.state_.func_["TaikoSelectCloseWaitSide2"] = function()
			-- 待ちどんちゃんを消す
			WaitDon:DispOff(1)
			WaitDon:DispOff(2)

			-- 立ち絵キャラ読み込み後の設定
			this:AfterLoadSetupStandChara()

			-- エントリー状態にあわせたどんちゃんとネームプレートの表示
			this:DispDonAndNamePlate()

			-- 二人目エントリー受付ウィンドウ
			local use_credit = false
			if(this.play_data_[1].is_use_credit == true) then
				this.credit_side_[1]:SetVisible(false)
				use_credit = true
			end
			if(this.play_data_[2].is_use_credit == true) then
				this.credit_side_[2]:SetVisible(false)
				use_credit = true
			end

			-- モード選択からきていたらモード選択に戻る
			if(this.taiko_select_from_modeselect_ == true) then
				this.state_:SetState("TaikoSelectCloseToModeSelect")
			else
				-- どちらもクレジットを消費していなければクレジット消費待ちに戻る
				if(use_credit == true) then
					this.state_:SetState("TaikoSelectCloseToModeSelect")
				else
					this.state_:SetState("CreditWaitStart")
				end
			end
		end

		this.state_.func_["TaikoSelectCloseToModeSelect"] = function()
			-- どんちゃん復活
			for loop_idx = 1,2 do
				if(this.play_data_[loop_idx].is_use_credit == true) then
					-- 参加アニメ
					Don.SetLoopAnimation((loop_idx - 1),"select_loop",true)
				end
			end
			this.state_:SetState("ModeSelectStart")
		end

		-- =============== ＱＲ使用確認（ＱＲ太鼓選択） ここから ===============
		this.state_.func_["QRTaikoSelectStart"] = function()
			this.taiko_select_mode_ = 1

			local card_data = PlayDataManager.GetCardReadData()
			if(card_data.qr_data.qrDataList_size > 0) then
				local qrCodeInfo = QRCodeInfo.create(card_data.qr_data.qrDataList[1].responseId)
				if(qrCodeInfo.unique_id ~= 0) then
					-- タイトルなどの設定
					QRTaikoSelect:SetupIDString(qrCodeInfo.id)
					QRTaikoSelect:SetupTitle()

					-- プレイヤー選択させるか
					local isPlayerSelect = false
					if( (qrCodeInfo.qrType == QRCodeType.kCostumeTrial) or
						(qrCodeInfo.qrType == QRCodeType.kCostumeGet)) then
						isPlayerSelect = true
					end
					if(qrCodeInfo.qrType == QRCodeType.kSongGet) then
						isPlayerSelect = true
					end
					QRTaikoSelect:SetupPlayerSelect(isPlayerSelect)

					-- 表示用データの読み込み開始
					QRTaikoSelect:LoadContents(qrCodeInfo.taikoselect_fla,qrCodeInfo.taikoselect_bg_fla)
				end
			end

			this.state_:SetState("QRTaikoSelectLoadContents")
		end
		this.state_.func_["QRTaikoSelectLoadContents"] = function()
			if(QRTaikoSelect:LoadingContents() == true) then
				QRTaikoSelect:SetVisible(true)
				QRTaikoSelect:Start(QR.EntryAvailable(0),QR.EntryAvailable(1))

				-- ボイスＳＥ「つかう太鼓をえらんでね！」
				TSound:Play("voice_common_v12a","taiko_choose")

				-- 操作ガイド消す
				this.control_guide_:SetVisible(false)
				this.start_guide_ = false

				-- タイマー再設定開始
				this.timer_:SetShadow(false)
				this.timer_:SetCount(40)
				this.timer_:StartCount()

				this.qr_taiko_select_result_ = TaikoSelect.EnumReturn.kDoing
				this.taiko_select_cansel_ = false

				this.work_counter_ = 0
				this.state_:SetState("QRTaikoSelect")
			end
		end
		this.state_.func_["QRTaikoSelect"] = function()
			local taiko_result = QRTaikoSelect:Update()

			if(this.taiko_select_cansel_ == false) then
				if(taiko_result == QRTaikoSelect.EnumReturn.kDoing) then
					if(this.timer_:IsZero() == true) then
						-- 時間切れさせる
						QRTaikoSelect:TimeUp()
						this.taiko_select_cansel_ = true
					end
				end
			end
			if(taiko_result == QRTaikoSelect.EnumReturn.kDecideWait) then
				-- カウント止めちゃう
				this.timer_:StopCount()
			end
			if((taiko_result ~= QRTaikoSelect.EnumReturn.kDoing) and (taiko_result ~= QRTaikoSelect.EnumReturn.kDecideWait)) then
				this.qr_taiko_select_result_ = taiko_result

				-- ここで太鼓選択消す
				QRTaikoSelect:Finish()

				this.work_counter_ = 0
				this.state_:SetState("QRTaikoSelectCloseStart")
			end
		end
		this.state_.func_["QRTaikoSelectCloseStart"] = function()
			if(this.work_counter_ >= (Common.FPS * 0.25)) then
				QRTaikoSelect:SetVisible(false)

				-- 向きを合わせる
				Don.CameraReverse(0,false)
				Don.CameraReverse(1,true)

				-- 一時停止解除
				Don.PauseAnimation(0,false)
				Don.PauseAnimation(1,false)

				-- タイマーリセット
				this.timer_:SetCount(60)

				-- 戻り変数を調整
				if(this.qr_taiko_select_result_ == QRTaikoSelect.EnumReturn.kCancel) then
					this.taiko_select_result_ = TaikoSelect.EnumReturn.kCancel
				end
				if(this.qr_taiko_select_result_ == QRTaikoSelect.EnumReturn.kDecideLeft) then
					this.taiko_select_result_ = TaikoSelect.EnumReturn.kDecideLeft
				end
				if(this.qr_taiko_select_result_ == QRTaikoSelect.EnumReturn.kDecideRight) then
					this.taiko_select_result_ = TaikoSelect.EnumReturn.kDecideRight
				end
				if(this.qr_taiko_select_result_ == QRTaikoSelect.EnumReturn.kDecideYes) then
					this.taiko_select_result_ = TaikoSelect.EnumReturn.kDecideYes
				end

				this.work_counter_ = 0
				this.state_:SetState("TaikoSelectCloseWaitDonLoad")
			end
		end

		-- =============== クレジット受付 ここから ===============
		this.state_.func_["CreditWaitStart"] = function()
			-- タイマー使わない
			this.timer_:SetShadow(true)
			this.timer_:SetCount(60)
			this.timer_:StopCount()

			-- クレジット受付ウィンドウ開始
			CreditWait:Start()
			CreditWait:SetVisible(true)
			this.old_card_result_ = 0
			this.old_qr_result_ = 0

			-- ボイス再生
			-- クレジットが成立していないとき
			if((PlayDataManager.GetNowCoin() < PlayDataManager.GameCost1) and (PlayDataManager.IsFreePlay() == false)) then
				-- 「コインを入れてね！」
				TSound:PlaySlot("voice_common_v12a","insert_credit_loop",kEntrySoundSlot_CautionVoice0)
			else
				-- 操作ガイド開始
--				this.control_guide_:SetVisible(true)
--				this.control_guide_:Start(1)

--				this.start_guide_ = true
			end

			this.work_counter_ = 0
			this.state_:SetState("CreditWaitIn")
		end
		this.state_.func_["CreditWaitIn"] = function()
			if(this.work_counter_ >= Common.FPS) then
				-- タイマーを動かすか
				if(this:IsTimerCountInCreditWait() == true) then
					this.timer_:SetShadow(false)
					this.timer_:StartCount()
				end

				this.state_:SetState("CreditWait")
			end
		end
		this.state_.func_["CreditWait"] = function()
			-- カード読み込み
			local card_result = CardLoad:Update()
			-- ＱＲ読み込み
			local qr_result = QRLoad:Update()

			if(card_result ~= this.old_card_result_) then
				this.old_card_result_ = card_result

				if(card_result ~= 0) then
					CreditWait:SetVisible(false)

					-- タイマー止める
					this.timer_:SetShadow(true)
					this.timer_:StopCount()
				end
			elseif(qr_result ~= this.old_qr_result_) then
				this.old_qr_result_ = qr_result

				if(qr_result ~= 0) then
					CreditWait:SetVisible(false)

					-- タイマー止める
					this.timer_:SetShadow(true)
					this.timer_:StopCount()
				end
			end

			-- カードもＱＲも何もなし
			if((card_result == 0) and (qr_result == 0)) then
				if(this.timer_:IsZero() == true) then
					-- アトラクトへ戻る
					this.state_:SetState("ReturnAttractEnd")
				else
					-- コイン状態反映はC側で回します
					-- エントリー待ち
					local old_entry = {this.play_data_[1].user_type,this.play_data_[2].user_type}
					local is_next = this:CheckEntry()
					if(is_next == true) then
						-- ＳＥ「大どん（中央）」
						TSound:Play("se_common_v12a","don_big")

						-- ＳＥ消す
						TSound:StopSlot(kEntrySoundSlot_CautionVoice0)

						-- 上の段光らせる
						CreditWait:Decide(1)

						this.work_counter_ = 0
						this.state_:SetState("CreditDecideAction")
					end
				end

				-- クレジット状態にあわせてボイス再生
				if(this.start_voice_ == false) then
					if((PlayDataManager.GetNowCoin() >= PlayDataManager.GameCost1) or (PlayDataManager.IsFreePlay() == true)) then
						-- ＳＥ消す
						TSound:StopSlot(kEntrySoundSlot_CautionVoice0)

						-- ボイスＳＥ「太鼓をたたいてスタート！」ループ
						TSound:PlaySlot("voice_common_v12a","entry_1p_primal_loop",kEntrySoundSlot_CautionVoice0)

						-- 
						this.start_voice_ = true
					end
				end
				-- 操作ガイド
				if(this.start_guide_ == false) then
					if((PlayDataManager.GetNowCoin() >= PlayDataManager.GameCost1) or (PlayDataManager.IsFreePlay() == true)) then
						-- 操作ガイド開始
						this.control_guide_:SetVisible(true)
						this.control_guide_:Start(1)
						this.start_guide_ = true
					end
				else
					-- 操作ガイド回す
					this.control_guide_:Update(true)
				end
			end
			-- どっちかエラー
			if((card_result == -1) or (qr_result == -1)) then
				-- エラー時

				-- カード読み込み表示開始（待機）
				this:RestartCardReadWait()

				CreditWait:SetVisible(true)

				-- タイマーを動かすか
				if(this:IsTimerCountInCreditWait() == true) then
					this.timer_:SetShadow(false)
					this.timer_:StartCount()
				end

				this.old_card_result_ = 0
			else
				-- カード優先
				if(card_result == 2) then
					-- 成功→使う太鼓選択へ
					this.taiko_select_mode_ = 0
					-- 太鼓選択開始
					this:TaikoSelectStart(false)
				elseif(qr_result == 2) then
					-- 成功→ＱＲ使う太鼓選択へ
					this.taiko_select_mode_ = 1
					-- 太鼓選択開始
					this:TaikoSelectStart(false)
				end
			end
		end
		this.state_.func_["CreditDecideAction"] = function()
			if(CreditWait:IsPlayDecide() == false) then
				-- クレジット受付全体のフェードアウト
				CreditWait:Finish()
				this.work_counter_ = 0
				this.state_:SetState("CreditFinishWait")
			end
		end
		this.state_.func_["CreditFinishWait"] = function()
			-- 演出終わりまで待つ
			if(CreditWait:IsPlay() == false) then
				-- クレジット受付消し
				CreditWait:SetVisible(false)

				this.work_counter_ = 0
				this.state_:SetState("ModeSelectStart")
			end
		end

		-- =============== モード選択 ここから ===============
		this.state_.func_["ModeSelectStart"] = function()
			if(this.work_counter_ >= (Common.FPS * 0.25)) then
				-- モード選択表示開始
				ModeSelect:Start(this.play_data_[1],this.play_data_[2])
				ModeSelect:SetVisible(true)

				this.state_:SetState("ModeSelectStartWait")
			end
		end
		this.state_.func_["ModeSelectStartWait"] = function()
			local mode_select_result = ModeSelect:Update(false,false)
			if(mode_select_result == ModeSelect.EnumReturn.kDoing) then

				-- 二人目エントリー受付ウィンドウ
				if(this.play_data_[1].is_use_credit == false) then
					this.credit_side_[1]:SetVisible(true)
					this.credit_side_[1]:Start()
				else
					this.credit_side_[1]:SetVisible(false)
				end
				if(this.play_data_[2].is_use_credit == false) then
					this.credit_side_[2]:SetVisible(true)
					this.credit_side_[2]:Start()
				else
					this.credit_side_[2]:SetVisible(false)
				end

				-- ボイスＳＥ「モードをえらんでね！」
				TSound:Play("voice_entry_v12a","mode_choose")
				ModeSelect:StartVoiceWait()

				-- タイマー再設定開始
				this.timer_:SetShadow(false)
				this.timer_:SetCount(60)
				this.timer_:StartCount()

				-- 操作ガイド開始
				if(this.start_guide_ == false) then
					this.control_guide_:SetVisible(true)
					this.control_guide_:Start(1)
					this.start_guide_ = true
				end

				-- 操作ガイド複数状態かチェック
				if(ModeSelect:GetMenuNum() > 1) then
					this.control_guide_:ChangeMode(0)
				end

				this.mode_select_timeup_ = false

				this.work_counter_ = 0
				this.state_:SetState("ModeSelect")
			end
		end
		this.state_.func_["ModeSelect"] = function()
			-- カード読み込み
			local card_result = CardLoad:Update()
			-- ＱＲ読み込み
			local qr_result = QRLoad:Update()

			if(card_result ~= this.old_card_result_) then
				this.old_card_result_ = card_result

				if(this.old_card_result_ == 0) then
					-- タイマー再開
					this.timer_:StartCount()
				else
					-- タイマー停止
					this.timer_:StopCount()
					-- モード選択停止
					ModeSelect:Stop()
				end
			elseif(qr_result ~= this.old_qr_result_) then
				this.old_qr_result_ = qr_result

				if(this.old_qr_result_ == 0) then
					-- タイマー再開
					this.timer_:StartCount()
				else
					-- タイマー停止
					this.timer_:StopCount()
					-- モード選択停止
					ModeSelect:Stop()
				end
			end

			-- カード、ＱＲ読み込みの反応
			-- どっちかエラー
			if((card_result == -1)  or (qr_result == -1)) then
				-- エラー時
				-- カード読み込み表示開始（待機）
				this:RestartCardReadWait()

				-- モード選択表示
				ModeSelect:SetVisible(true)
				ModeSelect:StartBanner()

				-- タイマー再開
				this.timer_:StartCount()

				this.old_card_result_ = 0
			else
				-- カード優先
				if(card_result == 2) then
					-- 成功
					-- タイマー止める
					this.timer_:StopCount()

					this.taiko_select_mode_ = 0

					this.work_counter_ = 0
					this.state_:SetState("ModeSelectToTaikoSelect")
				elseif(qr_result == 2) then
					-- 成功
					-- タイマー止める
					this.timer_:StopCount()

					this.taiko_select_mode_ = 1

					this.work_counter_ = 0
					this.state_:SetState("ModeSelectToTaikoSelect")
				end
			end

			-- カードもＱＲも反応ない場合
			if((card_result == 0) and (qr_result == 0)) then
				-- エントリー受付
				local old_entry = {this.play_data_[1].user_type,this.play_data_[2].user_type}
				local is_entry = this:CheckEntry()
				if(is_entry == true) then
					-- エントリーした
					if((old_entry[1] == UserType.kNone) and (this.play_data_[1].user_type ~= UserType.kNone)) then
						-- ＳＥ「小どん（左）」
						TSound:Play("se_common_v12a","don_l")
					elseif((old_entry[2] == UserType.kNone) and (this.play_data_[2].user_type ~= UserType.kNone)) then
						-- ＳＥ「小どん（右）」
						TSound:Play("se_common_v12a","don_r")
					else
						-- ＳＥ「小どん（中央）」
						TSound:Play("se_common_v12a","don_c")
					end

					for loop_idx = 1,2 do
						if(this.play_data_[loop_idx].user_type ~= UserType.kNone) then
							-- 二人目受付ウィンドウ
							this.credit_side_[loop_idx]:SetVisible(false)
						end
					end

					-- 看板構成が変化する場合
					if(ModeSelect:CheckBoardListChange(this.play_data_[1],this.play_data_[2]) == true) then
						-- リスト更新
						ModeSelect:ChangeBoardList(this.play_data_[1],this.play_data_[2])
						-- 操作ガイドはける
						if(this.start_guide_ == true) then
							this.control_guide_:OutSide()
							this.start_guide_ = false
						end

						this.state_:SetState("ModeSelectChangeList")
					end
				else
					-- エントリーしていないのでモード選択処理
					local entry_enable_1p = false
					local entry_enable_2p = false

					if((this.entry_wait_[1] <= 0) and (this.play_data_[1].is_use_credit == true)) then
						entry_enable_1p = true
					end
					if((this.entry_wait_[2] <= 0) and (this.play_data_[2].is_use_credit == true)) then
						entry_enable_2p = true
					end

					if(this.timer_:IsZero() == true) then
						-- 時間切れ
						ModeSelect:TimeUp()

						entry_enable_1p = false
						entry_enable_2p = false
					end

					local mode_select_result = ModeSelect:Update(entry_enable_1p,entry_enable_2p)
					if(mode_select_result == ModeSelect.EnumReturn.kDecide) then
						-- タイマー止める
						this.timer_:StopCount()

						-- エントリー締め切り
						this:EntryFinish()

						-- カードタッチ終了させる
						CardLoad:CardTouchWaitFinish()
						-- ＱＲタッチ終了させる
						QRLoad:TouchWaitFinish()

						-- 決定アニメ
						for loop_idx = 1,2 do
							if(this.play_data_[loop_idx].user_type ~= UserType.kNone) then
								this.don_[loop_idx]:GotoAndPlay("mode_select")
								Don.SetNonLoopAnimation((loop_idx - 1),"full_combo",true)

								-- 立ち絵
								if(this.stand_chara_enable_[loop_idx] == true) then
									this.stand_chara_[loop_idx]:GotoAndPlay("contents_"..loop_idx.."p_instance","decide")
								end
							end
						end

						-- 決まったモード取得
						this.mode_select_decide_ = ModeSelect:GetDecideMode()

						this.work_counter_ = 0
						this.state_:SetState("ModeSelectFinishActionWait")
					end
				end

				-- 操作ガイド回す
				this.control_guide_:Update(true)
			end
		end
		this.state_.func_["ModeSelectChangeList"] = function()
			local mode_select_result = ModeSelect:Update(false,false)
			if(mode_select_result == ModeSelect.EnumReturn.kDoing) then
				this.work_counter_ = 0
				this.state_:SetState("ModeSelect")

				-- 操作ガイド調整
				if(this.start_guide_ == false) then
					this.control_guide_:InSide()

					-- 操作ガイド複数状態かチェック
					if(ModeSelect:GetMenuNum() > 1) then
						this.control_guide_:ChangeMode(0)
					else
						this.control_guide_:ChangeMode(1)
					end

					this.start_guide_ = true
				end
			end
		end
		this.state_.func_["ModeSelectToTaikoSelect"] = function()
			if(this.work_counter_ >= (Common.FPS * 0.5)) then
				-- 太鼓選択開始
				this:TaikoSelectStart(true)
			end
		end
		this.state_.func_["ModeSelectFinishActionWait"] = function()
			if(this.work_counter_ >= (Common.FPS * 0.5)) then
				if(ModeSelect:IsPlayBoard() == false) then
					-- モード選択終了
					ModeSelect:Finish()
					-- 操作ガイド消す
					this.control_guide_:SetVisible(false)
					this.start_guide_ = false

					-- 二人目エントリー受付ウィンドウ
					this.credit_side_[1]:SetVisible(false)
					this.credit_side_[2]:SetVisible(false)

					-- ＳＥ消す
					TSound:StopSlot(kEntrySoundSlot_CautionVoice0)

					-- セッティングで必要な情報
					for loop_idx = 1,2 do
						this.setting_type_[loop_idx] = 0

						-- エントリー種別
						if(this.play_data_[loop_idx].user_type == UserType.kCoin) then
							-- コインユーザーはきせかえがついていなければコスチューム選択
							if(QR.IsUseCostume((loop_idx - 1)) == false) then
								this.setting_type_[loop_idx] = 1
							end
						elseif(this.play_data_[loop_idx].user_type == UserType.kCard) then
							-- カードユーザーは初めてならネームエントリー
							if(this.play_data_[loop_idx].is_new_data == true) then
								this.setting_type_[loop_idx] = 2
							end
						end
					end

					-- モード選択後のＱＲチェックへ
					this.work_counter_ = 0
					this.state_:SetState("ModeSelectQRCheck")
				end
			end
		end
		this.state_.func_["ModeSelectQRCheck"] = function()
			-- 選んだモードのＱＲチェック
			local selectScene = SceneType.kSongSelect
			if(this.mode_select_decide_ == GameMode.kDani) then
				selectScene = SceneType.kDaniSelect
			elseif(this.mode_select_decide_ == GameMode.kAI) then
				selectScene = SceneType.kAISelect
			end
			-- ＱＲコードの使用不可チェック、サーバー問い合わせの結果を無視する、エラー表示あり
			this:CheckQRDataAvailable(selectScene,true,true)

			-- セッティングが必要ない場合は終了
			if((this.setting_type_[1] == 0) and (this.setting_type_[2] == 0)) then
				-- 終了、曲選択へ
				this.work_counter_ = Common.FPS * 0.5
				this.state_:SetState("ToSongSelectAnimeWait")
			else
				this.work_counter_ = 0
				this.state_:SetState("ToSettingAnimeStart")
			end
		end
		this.state_.func_["ToSettingAnimeStart"] = function()
			-- 退出アニメ開始
			for loop_idx = 1,2 do
				if(this.play_data_[loop_idx].user_type ~= UserType.kNone) then
					this.don_[loop_idx]:GotoAndPlay("out")
					Don.SetNonLoopAnimation((loop_idx - 1),"normal",true)
				end
				-- 立ち絵消す
				this.stand_chara_[loop_idx]:SetVisible(false)
			end

			this.work_counter_ = 0
			this.state_:SetState("ToSettingAnimeWait")
		end
		this.state_.func_["ToSettingAnimeWait"] = function()
			if(this.work_counter_ >= (Common.FPS * 0.75)) then
				this.work_counter_ = 0
				this.state_:SetState("SettingStart")
			end
		end

		-- =============== セッティング ここから ===============
		-- メモ：セッティング以降は追加でエントリーできなくてよい
		this.state_.func_["SettingStart"] = function()
			-- コスチューム選択の開始
			CostumeSelect:SetVisible(true)
			-- ネームエントリーの開始
			NameEntry:SetVisible(true)
			-- 地の開始
			SettingBase:SetVisible(true)

			-- ＢＧＭ入れ替え
			TSound:SetVolumeSlot(kEntrySoundSlot_BGM0,-90.0,0)
			TSound:SetVolumeSlot(kEntrySoundSlot_BGM1,0.0,0)

			-- プレイヤー数設定
			CostumeSelect:SetPlayerNum(this.entry_count_)
			NameEntry:SetPlayerNum(this.entry_count_)
			SettingBase:SetPlayerNum(this.entry_count_)

			-- セッティングで必要な情報
			this.has_add_count_ = false
			for loop_idx = 1,2 do
				-- いったん処理済み
				CostumeSelect:SetFinish(loop_idx)
				NameEntry:SetFinish(loop_idx)

				-- プレイヤー情報消す
				this.player_info_[loop_idx]:SetVisible(false)
				-- 立ち絵消す
				this.stand_chara_[loop_idx]:SetVisible(false)

				-- エントリー種別
				if(this.setting_type_[loop_idx] == 2) then
					this.has_add_count_ = true
					-- ネームエントリー
					NameEntry:Start(loop_idx)
					-- ネームプレート消す
					this.name_plate_[loop_idx]:SetVisible(false)

					-- 地出す
					SettingBase:Start(loop_idx)
				elseif(this.setting_type_[loop_idx] == 1) then
					-- コスチューム選択
					CostumeSelect:Start(loop_idx)
					-- 3Dどん消す
					this.don_[loop_idx]:SetVisible(false)

					-- 地
					SettingBase:Start(loop_idx)
				else
					if(this.entry_count_ == 2) then
						-- 3Dどん消す
						this.don_[loop_idx]:SetVisible(false)

						-- 地
						SettingBase:Start(loop_idx)
					end
				end
			end

			this.state_:SetState("SettingStartWait")
		end
		this.state_.func_["SettingStartWait"] = function()
			if(this.work_counter_ >= (Common.FPS * 0.5)) then

				-- セッティングで必要な情報
				local next_timer = 60
				local is_name_entry = false
				for loop_idx = 1,2 do
					-- エントリー種別
					if(this.setting_type_[loop_idx] == 2) then
						is_name_entry = true
						next_timer = 100
					end
				end

				if(is_name_entry == true) then
					-- ボイスＳＥ「名前を決めてね！」
					TSound:Play("voice_entry_v12a","name_input")
				else
					-- ボイスＳＥ「きせかえをえらんでね！」
					TSound:Play("voice_entry_v12a","costume_choose")
				end

				-- タイマー再設定開始
				this.timer_:SetCount(next_timer)

				this.setting_timer_play_ = true
				this.setting_wait_upload_ = false

				for loop_idx = 1,2 do
					-- エントリー種別
					if(this.setting_type_[loop_idx] == 2) then
					elseif(this.setting_type_[loop_idx] == 1) then
						-- 煙出す
						CostumeSelect:StartSmoke(loop_idx)
						-- どんちゃん出す
						SettingBase:DispDon(loop_idx,true)
					else
						if(this.entry_count_ == 2) then
							-- ちょっと待ってね、どんちゃん出す
							SettingBase:DispDon(loop_idx,true)
							SettingBase:StartWait(loop_idx,false)
						end
					end
				end

				this.work_counter_ = 0
				this.state_:SetState("SettingStartWait2")
			end
		end
		this.state_.func_["SettingStartWait2"] = function()
			if(this.work_counter_ >= (Common.FPS * 1.0)) then
				-- タイマースタート
				this.timer_:StartCount()

				for loop_idx = 1,2 do
					if(this.setting_type_[loop_idx] == 1) then
						-- コスチューム選択
						CostumeSelect:StartSelect(loop_idx)
					end
					if(this.setting_type_[loop_idx] == 2) then
						-- ネームエントリー
						NameEntry:StartSelect(loop_idx)
					end
				end

				this.state_:SetState("Setting")
			end
			for loop_idx = 1,2 do
				if(this.setting_type_[loop_idx] == 0) then
					SettingBase:UpdateWait(loop_idx)
				end
				if(this.setting_type_[loop_idx] == 1) then
					-- コスチューム選択
					CostumeSelect:Update(loop_idx,this.setting_wait_upload_)
				end
				if(this.setting_type_[loop_idx] == 2) then
					-- ネームエントリー
					NameEntry:Update(loop_idx,this.setting_wait_upload_)
				end
			end
		end
		this.state_.func_["Setting"] = function()
			local is_next = false
			if(this.setting_timer_play_ == true) then
				if(this.timer_:IsZero() == true) then
					if(this.has_add_count_ == true) then
						-- タイマー再設定
						this.timer_:SetCount(30)
						this.timer_:StartCount()
						this.has_add_count_ = false
					else
						this.setting_timer_play_ = false

						-- ＳＥ「大どん（中央）」
						TSound:Play("se_common_v12a","don_big")
						is_next = true

						-- ネームエントリーの場合その時点で強制設定、通信待ち
						for loop_idx = 1,2 do
							if(this.setting_type_[loop_idx] == 1) then
								-- 時間切れ処理
								CostumeSelect:TimeUp(loop_idx)
								is_next = false
							end
							if(this.setting_type_[loop_idx] == 2) then
								-- 時間切れ処理
								NameEntry:TimeUp(loop_idx)
								is_next = false
							end
						end
					end
				end
			end

			if(is_next == false) then
				local finish_flag = {true,true}
				for loop_idx = 1,2 do
					if(this.setting_type_[loop_idx] == 0) then
						SettingBase:UpdateWait(loop_idx)
					end
					if(this.setting_type_[loop_idx] == 1) then
						-- コスチューム選択
						finish_flag[loop_idx] = CostumeSelect:Update(loop_idx,this.setting_wait_upload_)
					end
					if(this.setting_type_[loop_idx] == 2) then
						-- ネームエントリー
						local name_entry_ret = NameEntry:Update(loop_idx,this.setting_wait_upload_)
						if(name_entry_ret == NameEntry.EnumReturn.kUpload) then

							-- アップロード開始でカウンター止める
							this.timer_:StopCount()
							this.setting_wait_upload_ = true

							finish_flag[loop_idx] = false
						elseif(name_entry_ret == NameEntry.EnumReturn.kFinish) then
							if(this.setting_wait_upload_ == true) then
								this.timer_:StartCount()
								this.setting_wait_upload_ = false
							end

							finish_flag[loop_idx] = true
						else
							if(this.setting_wait_upload_ == true) then
								this.timer_:StartCount()
								this.setting_wait_upload_ = false
							end

							finish_flag[loop_idx] = false
						end
					end
				end

				for loop_idx = 1,2 do
					-- セッティングを決定したときの処理
					if((this.setting_type_[loop_idx] ~= 0) and (finish_flag[loop_idx] == true)) then
						-- どんちゃん位置変える
						this.don_[loop_idx]:SetVisible(false)
						this.stand_chara_[loop_idx]:SetVisible(false)
						SettingBase:DispDon(loop_idx,true)

						-- 次に進まない場合はボイスを鳴らす「ヨシ！」
						if((finish_flag[1] == false) or (finish_flag[2] == false)) then
							if(this.entry_count_ == 1) then
								TSound:Play("voice_common_v12a","costume_decide_1_c")
							else
								if(loop_idx == 1) then
									TSound:Play("voice_common_v12a","costume_decide_1_l")
								else
									TSound:Play("voice_common_v12a","costume_decide_1_r")
								end
							end
						end

						-- この時点でのユーザー情報取得
						this.play_data_[loop_idx] = PlayDataManager.GetEntryPlayData((loop_idx - 1))

						-- ちょっと待ってね表示
						SettingBase:StartWait(loop_idx,true)

						-- ネームプレートはまた出す
						this.name_plate_[loop_idx]:SetPlayerInfo(loop_idx)
						this.name_plate_[loop_idx]:SetVisible(true)

						this.setting_type_[loop_idx] = 0
					end
				end

				if((finish_flag[1] == true) and (finish_flag[2] == true)) then
					is_next = true
				end
			end

			if(is_next == true) then
				-- 終了、各種反映後曲選択へ
				this.timer_:StopCount()

				-- 終了の処理
				SettingBase:StartSelectFinishAll()

				this.work_counter_ = 0
				this.state_:SetState("ToSongSelectAnimeWait")
			end
		end
		this.state_.func_["ToSongSelectAnimeWait"] = function()
			if(this.work_counter_ >= (Common.FPS * 1.5)) then
				this.state_:SetState("ToSongSelectAnimeWaitCheckUserData")
			end
		end
		this.state_.func_["ToSongSelectAnimeWaitCheckUserData"] = function()
			-- ユーザーデータの準備完了チェックとＱＲチェックがすでに終わっているか
			if((this:CheckUserDataAvailable() == UserDataStatus.kAvailable) and (this.check_qr_start_ == false)) then
				-- ＱＲ使用するか
				if(QR.CheckNeedQRExecAll(SceneType.kEntry) == true) then
					-- ＱＲ使用へ
					NetAccessWindow.StartLoading("now_datacheck")
					this.state_:SetState("ToWaitExecQR")
				else
					-- 曲選択へ
					this.state_:SetState("ToSongSelectEnd")
				end
			else
				-- 待たせる
				NetAccessWindow.StartLoading("now_datacheck")
				this.state_:SetState("ToWaitUserData")
			end
		end

		this.state_.func_["ToWaitUserData"] = function()
			if(NetAccessWindow.IsPlay() == false) then
				this.state_:SetState("WaitUserData")
			end
		end
		this.state_.func_["WaitUserData"] = function()
			-- ＱＲチェックが終わるまで
			if(this.check_qr_start_ == false) then
				-- ユーザーデータの準備完了チェック
				local check_result = this:CheckUserDataAvailable()
				if(check_result == UserDataStatus.kAvailable) then
					-- ＱＲ使用するか
					if(QR.CheckNeedQRExecAll(SceneType.kEntry) == true) then
						-- ＱＲ使用へ
						this.state_:SetState("ToWaitExecQR")
					else
						-- 読み込み中を閉じる
						NetAccessWindow.Close()
						this.state_:SetState("WaitUserDataToEnd")
					end
				end
				if(check_result == UserDataStatus.kError) then
					-- 読み込み中を閉じる
					NetAccessWindow.Close()
					this.work_counter_ = 0
					this.state_:SetState("ToWaitUserDataError")
				end
			end
		end
		this.state_.func_["ToWaitUserDataError"] = function()
			if(NetAccessWindow.IsPlay() == false) then
				-- 「通信に失敗しました」
				NetAccessWindow.StartError("connectserver_error","userdata_get_error_sub")
				-- ＳＥ「バナパスポート読み込み失敗」
				TSound:Play("se_common_v12a","card_error")

				-- コインプレイにする
				for loop_idx = 1,2 do
					-- カードユーザー
					if(this.play_data_[loop_idx].user_type == UserType.kCard) then
						-- エラー
						if(PlayDataManager.GetUserDataStatus((loop_idx - 1)) == UserDataStatus.kError) then
							PlayDataManager.ChangeToCoinUser((loop_idx - 1))
							this.play_data_[loop_idx] = PlayDataManager.GetEntryPlayData((loop_idx - 1))

							-- QRチェック開始
							NetAccess.StartQRCheckAll()
						end
					end
				end

				this.work_counter_ = 0
				this.state_:SetState("WaitUserDataError")
			end
		end
		this.state_.func_["WaitUserDataError"] = function()
			local verify_result = NetAccess.ProcQRCheck()
			-- ２秒くらい
			if(this.work_counter_ >= (Common.FPS * 2.0)) then
				if((verify_result == GameConnectStatus.kSuccess) or (verify_result == GameConnectStatus.kError)) then
					-- ＱＲコードの使用不可チェック、サーバー問い合わせの結果を無視しない、エラー表示なし
					this:CheckQRDataAvailable(SceneType.kNone,false,false)

					-- ＱＲ使用するか
					if(QR.CheckNeedQRExecAll(SceneType.kEntry) == true) then
						-- ＱＲ使用へ
						this.state_:SetState("ToWaitExecQR")
					else
						-- 読み込み中を閉じる
						NetAccessWindow.Close()
						this.state_:SetState("WaitUserDataToEnd")
					end
				end
			end
		end
		this.state_.func_["WaitUserDataToEnd"] = function()
			if(NetAccessWindow.IsPlay() == false) then
				NetAccessWindow.CloseAll()
				-- 曲選択へ
				this.state_:SetState("ToSongSelectEnd")
			end
		end

		this.state_.func_["ToWaitExecQR"] = function()
			if(NetAccessWindow.IsPlay() == false) then
				-- ＱＲ使用を開始する
				QR.StartQRExecAll(SceneType.kEntry)
				-- ＱＲ使用の結果待ちへ
				this.state_:SetState("WaitExecQR")
			end
		end
		this.state_.func_["WaitExecQR"] = function()
			-- 実行中以外になったらおしまい
			if(QR.ProcExecQRAll() ~= GameConnectStatus.kDoing) then
				-- 読み込み中を閉じる
				NetAccessWindow.Close()
				this.state_:SetState("WaitUserDataToEnd")
			end
		end

		this.state_.func_["ToSongSelectEnd"] = function()
			-- シーン終了
			-- １人プレイ時に２Ｐのユーザー情報を１Ｐにコピーする
			PlayDataManager.CopySingle2PTo1P()

			-- 最終的にどのモードに遷移するべきかここで判定する
			local is_next_ok = true
			-- 段位に行きたいが・・・
			if(this.mode_select_decide_ == GameMode.kDani) then
				is_next_ok = false
				-- 段位に行っちゃダメなパターンチェック
				if(PlayDataManager.GetEntryUserCount() == 1) then
					if((PlayDataManager.GetUserType(0) == UserType.kCard) or (PlayDataManager.GetUserType(1) == UserType.kCard)) then
						-- 一人でカードのみＯＫ
						is_next_ok = true
					end
				end
			end
			-- ＡＩに行きたいけど
			if(this.mode_select_decide_ == GameMode.kAI) then
				is_next_ok = false
				-- ＡＩに行っちゃダメなパターンチェック
				if(PlayDataManager.GetEntryUserCount() == 1) then
					if((PlayDataManager.GetUserType(0) == UserType.kCard) or (PlayDataManager.GetUserType(1) == UserType.kCard)) then
						-- 一人でカードのみ
						is_next_ok = true
					end
				end
			end
			-- 
			if(is_next_ok == false) then
				this.mode_select_decide_ = GameMode.kEnso
			end

			if(this.mode_select_decide_ == GameMode.kDani) then
				Common.LuaFinish(SceneType.kDaniSelect)
			elseif(this.mode_select_decide_ == GameMode.kAI) then
				Common.LuaFinish(SceneType.kAISelect)
			else
				Common.LuaFinish(SceneType.kSongSelect)
			end
			this.state_:SetState("End")
		end

		this.state_.func_["ReturnAttractEnd"] = function()
			-- シーン終了
			Common.LuaFinish(SceneType.kAttract)
			this.state_:SetState("End")
		end

		this.state_.func_["End"] = function()
		end
	end,

	Update = function(this)
		if(this.update_func_name_ == "normal") then
			this:UpdateNormal()
		elseif(this.update_func_name_ == "error") then
			this:UpdateVerifyError()
		elseif(this.update_func_name_ == "errorclose") then
			this:UpdateVerifyErrorClose()
		end

		if(this.update_func_stand_chara_ == "loadwait") then
			this:UpdateLoadWaitStandChara()
		elseif(this.update_func_stand_chara_ == "loadwait2") then
			this:UpdateLoadWaitStandChara2()
		end
	end,

	UpdateNormal = function(this)
		-- ステートマシン実行
		this.state_:Update()

		-- タイマー実行
		this.timer_:Update()

		-- プレイヤー情報の更新
		this.player_info_[1]:Update(1)
		this.player_info_[2]:Update(2)

		-- ユーザーデータの取得
		this:UserDataGetRequest()

		-- ＱＲコードの状態確認
		this:UpdateQRCodeVerifyUserData()

		-- カウンター
		this.work_counter_ = this.work_counter_ + 1

		for loop_idx = 1,2 do
			if(this.entry_wait_[loop_idx] > 0) then
				this.entry_wait_[loop_idx] = this.entry_wait_[loop_idx] - 1
			end
		end
	end,
	UpdateVerifyError = function(this)
		this.disp_error_count_ = this.disp_error_count_ + 1
		-- ２秒くらい
		if((this.disp_error_count_ >= (Common.FPS * 2.0)) and (this.update_func_stand_chara_ == "none")) then
			QRAccessWindow.Close()
			this.update_func_name_ = "errorclose"
		end
	end,
	UpdateVerifyErrorClose = function(this)
		if(QRAccessWindow.IsPlay() == false) then
			QRAccessWindow.CloseAll()
			this.update_func_name_ = "normal"
		end
	end,
	UpdateLoadWaitStandChara = function(this)
		if ((SettingBase:LoadingStandFla() == true) and (Lumen.IsLoadMovieFinish() == true)) then
			this.update_func_stand_chara_ = "loadwait2"
		end
	end,
	UpdateLoadWaitStandChara2 = function(this)
		-- 立ち絵キャラ読み込み後の設定
		this:AfterLoadSetupStandChara()
		this.update_func_stand_chara_ = "none"
	end,

	TaikoSelectStart = function(this,is_modeselect)
		-- 使う太鼓選択へ
		this.taiko_select_from_modeselect_ = is_modeselect
		this.work_counter_ = 0

		if(this.taiko_select_mode_ == 0) then
			this.state_:SetState("CardTaikoSelectStart")
		elseif(this.taiko_select_mode_ == 1) then
			this.state_:SetState("QRTaikoSelectStart")
		end
	end,

	CheckEntry = function(this)
		local is_entry = false
		-- １Ｐ側ドン入力
		if((Input.GetTrigger(Input.PLAYER1_OK) == true) or (Input.GetTrigger(Input.PLAYER1_CANCEL) == true)) then
			is_entry = this:Entry(1,UserType.kCoin)
		-- ２Ｐ側ドン入力
		elseif((Input.GetTrigger(Input.PLAYER2_OK) == true) or (Input.GetTrigger(Input.PLAYER2_CANCEL) == true)) then
			is_entry = this:Entry(2,UserType.kCoin)
		end

		-- 立ち絵
		if(is_entry ==  true) then
			for loop_idx = 1,2 do
				if(this.stand_chara_enable_[loop_idx] == true) then
					if(this.play_data_[loop_idx].is_use_credit == true) then
						this.stand_chara_[loop_idx]:GotoAndPlay("contents_"..loop_idx.."p_instance","wait")
					else
						this.stand_chara_[loop_idx]:GotoAndPlay("contents_"..loop_idx.."p_instance","wait_gray")
					end
				end
			end
		end

		return is_entry
	end,

	Entry = function(this,index,userType)
		-- 古い衣装を取得する
		this:SaveCostumeForReload()
		-- エントリー処理
		local retFlag = PlayDataManager.Entry((index - 1),userType)
		if(retFlag == true) then
			this:EntrySuccess(index,false)
		end
		return retFlag
	end,
	QREntry = function(this,index)
		-- 古い衣装を取得する
		this:SaveCostumeForReload()
		-- エントリー処理
		local retFlag = PlayDataManager.QREntry((index - 1))
		if(retFlag == true) then
			this:EntrySuccess(index,true)
		end
		return retFlag
	end,
	EntrySuccess = function(this,index,isQR)
		-- 成功したら情報取得
		this.entry_count_ = PlayDataManager.GetEntryUserCount()
		this.card_entry_count_ = PlayDataManager.GetCardEntryUserCount()

		-- エントリー前の情報をとっておく
		local before_user_type = this.play_data_[index].user_type
		local before_use_credit = this.play_data_[index].is_use_credit
		-- luaのプレイヤー情報をここで更新
		this.play_data_[index] = PlayDataManager.GetEntryPlayData((index - 1))

		-- ループモーション設定
		Don.SetLoopAnimation((index - 1),"select_loop",true)

		-- どんちゃんをプレイデータ状態に
		this.don_[index]:SetVisible(true)
		-- クレジットあり
		if(this.play_data_[index].is_use_credit == true) then
			-- 参加アニメ
			local don_in_type = 0
			if(isQR == false) then
			-- カードエントリー
				if(before_user_type == UserType.kCard) then
					-- 直前カードユーザー→コイン投入（この場合はお金入れて有効になった=>どんちゃんは変化せず、飛んで回る）
					don_in_type = 0
				elseif(before_user_type == UserType.kCoin) then
					-- 直前コインユーザー→コイン投入
					if(this.play_data_[index].user_type == UserType.kCard) then
						-- カードユーザーに変わった=>どんちゃんは変化する
						don_in_type = 1
					else
						-- コインユーザーのまま（お金入れて有効になった=>どんちゃんは変化せず、飛んで回る）
						don_in_type = 0
					end
				else
					-- 不参加→コイン投入（どんちゃんが入ってくる）
					don_in_type = 2
				end
			else
			-- ＱＲエントリー
				if(before_user_type == UserType.kNone) then
					-- 不参加→コイン投入（どんちゃんが入ってくる）
					don_in_type = 2
				else
					-- 直前カード、直前コインどちらも＋ＱＲに代わる=>どんちゃんが変化する
					don_in_type = 1
				end
			end

			-- どんちゃんが変化するエントリーパターンでも実際にはどんちゃんが変化しないこともある
			if(don_in_type == 1) then
				local newCostume = PlayDataManager.GetUserClothes((index - 1))
				local newStandFla = PlayDataManager.GetUserStandCharaFla((index - 1))
				if(	(this:IsCostumeSame(newCostume,this.old_costume_[index]) == true) and
					(newStandFla == this.old_stand_fla_[index])) then
					don_in_type = 0
				end
			end

			if(don_in_type == 0) then
				-- どんちゃんが変化しないパターン
				-- 飛んで回る
				this.don_[index]:GotoAndPlay("mode_select")
				Don.SetNonLoopAnimation((index - 1),"full_combo",false)
			elseif(don_in_type == 1) then
				-- どんちゃんが変化するパターン
				-- どんちゃんを読み込む
				Don.ChangeDonForPlayDataOnly((index - 1))
				-- 待ちどんちゃん用の煙出す
				WaitDon:DispSmokeForced(this.entry_count_,index)
				-- 定位置
				this.don_[index]:GotoAndStop("init")
			else
				-- どんちゃんが入ってくるパターン
				-- どんちゃんを読み込む
				Don.ChangeDonForPlayDataOnly((index - 1))
				-- 飛び込んでくる
				this.don_[index]:GotoAndPlay("framein")
				Don.SetNonLoopAnimation((index - 1),"entry_in",false)
			end
		else
			local needSmoke = false
			if(before_user_type ~= UserType.kNone) then
				-- 直前カード、直前コインからクレジットなしの場合
				-- どんちゃんが変化するなら煙出す
				local newCostume = PlayDataManager.GetUserClothes((index - 1))
				local newStandFla = PlayDataManager.GetUserStandCharaFla((index - 1))
				if(	(this:IsCostumeSame(newCostume,this.old_costume_[index]) == false) or
					(newStandFla ~= this.old_stand_fla_[index])) then
					needSmoke = true
				end
			end

			-- どんちゃんを読み込む
			Don.ChangeDonForPlayDataOnly((index - 1))
			if(needSmoke == true) then
				-- 待ちどんちゃん用の煙出す
				WaitDon:DispSmokeForced(this.entry_count_,index)
			end

			-- 参加アニメ
			this.don_[index]:GotoAndPlay("don_gray")
			Don.SetNonLoopAnimation((index - 1),"select_loop",false)
		end

		-- 立ち絵の読み込み
		this:LoadChangeStandChara(index)

		-- ネームプレート更新
		this.name_plate_[index]:SetVisible(true)
		this.name_plate_[1]:SetPlayerInfo(1)
		this.name_plate_[2]:SetPlayerInfo(2)

		-- プレイヤー情報更新
		this.player_info_[index]:SetVisible(true)
		this.player_info_[1]:SetPlayerInfo(1,-1)
		this.player_info_[2]:SetPlayerInfo(2,-1)

		-- プレイヤーデータの取得開始
		-- カードユーザー / コイン投入済み / 新規カード以外
--		if((this.play_data_[index].is_use_credit == true) and (this.play_data_[index].user_type == UserType.kCard) and (this.play_data_[index].is_new_data == false)) then

		-- 直前がカードユーザー以外 / カードユーザー / 新規カード以外
		if((before_user_type ~= UserType.kCard) and (this.play_data_[index].user_type == UserType.kCard) and (this.play_data_[index].is_new_data == false)) then
			-- 取得開始のリクエストを出す→後で取得される
			PlayDataManager.UserDataRequestRequestWait((index - 1))
		end

		-- ＱＲのチェック開始する
		this:StartQRCodeVerifyUserData()

		this.entry_wait_[index] = (Common.FPS * 1.5)

		-- 参加ボイス
		if((this.play_data_[index].is_use_credit == true) and (before_use_credit == false)) then
			if(this.entry_count_ == 1) then
				-- ボイスＳＥ「参加だドン！」
				TSound:Play("voice_common_v12a","entry_join_c")
			else
				if(index == 1) then
					-- ボイスＳＥ「参加だドン！」
					TSound:Play("voice_common_v12a","entry_join_l")
				else
					-- ボイスＳＥ「参加だドン！」
					TSound:Play("voice_common_v12a","entry_join_r")
				end
			end
		end
	end,

	EntryFinish = function(this)
		-- 古い衣装を取得する
		this:SaveCostumeForReload()
		-- コイン使ってないユーザーを消す
		PlayDataManager.ClearNoCreditEntry()
		-- 情報取得しなおし→確定
		this:SetupEntryData()
	end,

	SetupEntryData = function(this)
		this.entry_count_ = PlayDataManager.GetEntryUserCount()
		this.card_entry_count_ = PlayDataManager.GetCardEntryUserCount()

		this.play_data_[1] = PlayDataManager.GetEntryPlayData(0)
		this.play_data_[2] = PlayDataManager.GetEntryPlayData(1)

		-- エントリー状態にあわせたどんちゃんとネームプレートの表示
		this:DispDonAndNamePlate()

		-- ネームプレート
		this.name_plate_[1]:SetPlayerInfo(1)
		this.name_plate_[2]:SetPlayerInfo(2)

		-- プレイヤー情報
		this.player_info_[1]:SetVisible(true)
		this.player_info_[2]:SetVisible(true)
		this.player_info_[1]:SetPlayerInfo(1,-1)
		this.player_info_[2]:SetPlayerInfo(2,-1)
	end,

	DispDonAndNamePlate = function(this)
		for loop_idx = 1,2 do
			if(this.play_data_[loop_idx].user_type ~= UserType.kNone) then
				-- ネームプレート
				this.name_plate_[loop_idx]:SetVisible(true)
				-- ３Ｄどんちゃん
				this.don_[loop_idx]:SetVisible(true)

				-- 立ち絵
				if(this.stand_chara_enable_[loop_idx] == true) then
					this.stand_chara_[loop_idx]:SetVisible(true)
					if(this.play_data_[loop_idx].is_use_credit == true) then
						this.stand_chara_[loop_idx]:GotoAndPlay("contents_"..loop_idx.."p_instance","wait")
					else
						this.stand_chara_[loop_idx]:GotoAndPlay("contents_"..loop_idx.."p_instance","wait_gray")
					end
				else
					this.stand_chara_[loop_idx]:SetVisible(false)
				end
			else
				this.name_plate_[loop_idx]:SetVisible(false)
				this.don_[loop_idx]:SetVisible(false)
				this.stand_chara_[loop_idx]:SetVisible(false)
			end
		end
	end,

	-- ユーザーデータの準備ができているか確認
	CheckUserDataAvailable = function(this)
		for loop_idx = 1,2 do
			-- カードユーザー
			if(this.play_data_[loop_idx].user_type == UserType.kCard) then
				-- どちらかが終了していない間は処理中
				if(PlayDataManager.GetUserDataStatus((loop_idx - 1)) == UserDataStatus.kNone) then
					return UserDataStatus.kNone
				end
			end
		end

		for loop_idx = 1,2 do
			-- カードユーザー
			if(this.play_data_[loop_idx].user_type == UserType.kCard) then
				-- どちらかがエラー
				if(PlayDataManager.GetUserDataStatus((loop_idx - 1)) == UserDataStatus.kError) then
					return UserDataStatus.kError
				end
			end
		end
		-- 完了
		return UserDataStatus.kAvailable
	end,

	-- ユーザーデータの取得
	UserDataGetRequest = function(this)
		-- 前のフレームでユーザーデータ取得ＯＫだったら取りに行く
		for loop_idx = 1,2 do
			if((this.user_data_request_ok_[loop_idx] == true) and (PlayDataManager.UserDataRequestAvailable((loop_idx - 1)) == true)) then
				-- プレイヤーデータの取得開始
				NetAccess.StartGetUserData((loop_idx - 1))
			end
		end

		for loop_idx = 1,2 do
			-- ユーザーデータのリクエストを送って良くなったら（ユーザーデータ取得のリクエスト待ち、かつ前のリクエストが終了している）
			if(PlayDataManager.UserDataRequestAvailable((loop_idx - 1)) == true) then
				-- 次のフレームに取りに行く
				this.user_data_request_ok_[loop_idx] = true
			else
				-- 取りに行かない
				this.user_data_request_ok_[loop_idx] = false
			end
		end
	end,

	-- カード読み込み再開
	RestartCardReadWait = function(this)
		-- カードは追加読み込みしないことがある
		if(this.card_entry_count_ < 2) then
			CardLoad:CardTouchWaitStart(true)
		else
			CardLoad:CardTouchWaitFinish()
		end

		-- QRは常に追加読み込みする
		QRLoad:TouchWaitStart(true,SceneType.kEntry)
	end,


	-- エントリー後のＱＲコードの状態確認
	StartQRCodeVerifyUserData = function(this)
		NetAccess.StartQRCheckAll()
		this.check_qr_start_ = true
	end,
	CheckQRDataAvailable = function(this,checkScene,skipGS,dispError)
		-- ＱＲコードの使用不可チェック
		local check_result = QR.CheckQRDataAvailable(checkScene,skipGS)
		if(check_result ~= CardTouchError.kNone) then

			-- 古い衣装を取得する
			this:SaveCostumeForReload()
			-- 使えなくなったＱＲを削除する
			QR.DeleteMarkedQRData()
			-- 変化したどんちゃんを読み込み直す
			this:ReloadChange3DDon()

			this.update_func_stand_chara_ = "loadwait"

			if(dispError == true) then
				-- エラーメッセージ
				this.disp_error_count_ = 0
				this.update_func_name_ = "error"

				local key_sub = "connectserver_qr_error_sub"

				if(check_result == CardTouchError.kItemHave) then
					key_sub = "qrcode_haveitem_sub"
				end
				if(check_result == CardTouchError.kOverUserCount) then
					key_sub = "qrcode_overusercount_sub"
				end
				if(check_result == CardTouchError.kOverTime) then
					key_sub = "qrcode_overtime_sub"
				end
				if(check_result == CardTouchError.kCardOnly) then
					key_sub = "qrcode_cardonly_sub"
				end
				if(check_result == CardTouchError.kNoCardOnly) then
					key_sub = "qrcode_nocardonly_sub"
				end
				if(check_result == CardTouchError.kSingleOnly) then
					key_sub = "qrcode_singleonly_sub"
				end
				if(check_result == CardTouchError.kModeNG) then
					key_sub = "qrcode_modeng_sub"

					if(checkScene == SceneType.kDaniSelect) then
						key_sub = "qrcode_modeng_dani_sub"
					elseif(checkScene == SceneType.kAISelect) then
						key_sub = "qrcode_modeng_ai_sub"
					elseif(checkScene == SceneType.kSongSelect) then
						key_sub = "qrcode_modeng_song_sub"
					end
				end

				QRAccessWindow.StartError("qrcode_cancel_error",key_sub)
				-- ＳＥ「バナパスポート読み込み失敗」
				TSound:Play("se_common_v12a","card_error")
			end

			return false
		end
		return true
	end,
	UpdateQRCodeVerifyUserData = function(this)
		-- QRチェックの結果を確認
		if(this.check_qr_start_ == true) then
			local verify_result = NetAccess.ProcQRCheck()
			if((verify_result == GameConnectStatus.kSuccess) or (verify_result == GameConnectStatus.kError)) then
				-- ＱＲコードの使用不可チェック、サーバー問い合わせの結果を無視しない、エラー表示あり
				this:CheckQRDataAvailable(SceneType.kNone,false,true)
				this.check_qr_start_ = false
			end
		end
	end,

	SaveCostumeForReload = function(this)
		for loop_idx = 1,2 do
			this.old_stand_fla_[loop_idx] = ""
			this.old_costume_[loop_idx].head = 0
			this.old_costume_[loop_idx].body = 0
			this.old_costume_[loop_idx].face = 0
			this.old_costume_[loop_idx].puchi = 0
			this.old_costume_[loop_idx].kigurumi = 0
			this.old_costume_[loop_idx].faceColor = 0
			this.old_costume_[loop_idx].bodyColor = 0
			this.old_costume_[loop_idx].legsColor = 0

			if(PlayDataManager.GetUserType((loop_idx - 1)) ~= UserType.kNone) then
				this.old_stand_fla_[loop_idx] = PlayDataManager.GetUserStandCharaFla((loop_idx - 1))
				this.old_costume_[loop_idx] = PlayDataManager.GetUserClothes((loop_idx - 1))
			end
		end
	end,
	ReloadChange3DDon = function(this)
		-- 変化したどんちゃんを読み込み直す
		for loop_idx = 1,2 do
			this:ReloadChange3DDonOnly(loop_idx)
		end
	end,
	ReloadChange3DDonOnly = function(this,playerId)
		-- 不参加は処理しない・・・
		if(PlayDataManager.GetUserType((playerId - 1)) == UserType.kNone) then
			return
		end

		local needSmoke = false
		-- どんちゃんの読み込み
		local newCostume = PlayDataManager.GetUserClothes((playerId - 1))
		if(this:IsCostumeSame(newCostume,this.old_costume_[playerId]) == false) then
			Don.ChangeDonForPlayDataOnly((playerId - 1))
			needSmoke = true
		end

		-- 立ち絵の読み込み
		if(this:LoadChangeStandChara(playerId) == true) then
			needSmoke = true
		end

		if(needSmoke == true) then
			-- 待ちどんちゃん用の煙出す
			WaitDon:DispSmokeForced(this.entry_count_,playerId)
		end
	end,
	LoadChangeStandChara = function(this,playerId)
		local needSmoke = false
		local standFla = PlayDataManager.GetUserStandCharaFla((playerId - 1))
		if(standFla ~= "") then
			-- flaファイルが異なる場合はロードムービー
			if(standFla ~= this.old_stand_fla_[playerId]) then
				-- 通常
				Lumen.LoadMovie("lumen/"..standFla,"stand_chara_instance_"..playerId)

				-- ちょっと待ってね用
				SettingBase:LoadStandFla(playerId,"lumen/"..standFla)
				needSmoke = true
			end
			this.stand_chara_enable_[playerId] = true
		else
			if(standFla ~= this.old_stand_fla_[playerId]) then
				needSmoke = true
			end
			this.stand_chara_enable_[playerId] = false
			-- ちょっと待ってね用
			SettingBase:DisableStandChara(playerId)
		end

		return needSmoke
	end,
	AfterLoadSetupStandChara = function(this)
		this.stand_chara_[1] = Lumen.GetMovieClip("stand_chara_instance_1",true)
		this.stand_chara_[2] = Lumen.GetMovieClip("stand_chara_instance_2",true)
		this.stand_chara_[1]:SetVisible(false)
		this.stand_chara_[2]:SetVisible(false)
		if(this.stand_chara_enable_[1] == true) then
			this.stand_chara_[1]:GotoAndStop("keep")
			this.stand_chara_[1].main_instance:GotoAndStop("1p")
		end
		if(this.stand_chara_enable_[2] == true) then
			this.stand_chara_[2]:GotoAndStop("keep")
			this.stand_chara_[2].main_instance:GotoAndStop("2p")
		end
	end,

	-- 着せ替えの一致確認
	IsCostumeSame = function(this,cos1,cos2)
		if(	(cos1.head == cos2.head) and
			(cos1.body == cos2.body) and
			(cos1.face == cos2.face) and
			(cos1.puchi == cos2.puchi) and
			(cos1.kigurumi == cos2.kigurumi) and
			(cos1.faceColor == cos2.faceColor) and
			(cos1.bodyColor == cos2.bodyColor) and
			(cos1.legsColor == cos2.legsColor)) then
			return true
		end

		return false
	end,

	-- クレジット待ちでタイマー動かすか
	IsTimerCountInCreditWait = function(this)
		-- カードユーザーがいる場合はタイマーを動かす
		if((this.play_data_[1].user_type == UserType.kCard) or (this.play_data_[2].user_type == UserType.kCard)) then
			return true
		end
		-- ＱＲがついている場合はタイマーを動かす
		if((this.play_data_[1].qr_data.qrDataList_size > 0) or (this.play_data_[2].qr_data.qrDataList_size > 0)) then
			return true
		end
		-- ＱＲが共通領域に保存されている場合はタイマーを動かす
		if(QR.HasCommonQRData() == true) then
			return true
		end
		return false
	end,
}
