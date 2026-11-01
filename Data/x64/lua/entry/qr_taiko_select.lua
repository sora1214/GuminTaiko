-- ＱＲ使用確認（使う太鼓選択）
QRTaikoSelect = {
	-- 戻りの定数的な
	EnumReturn = {
		kDoing = 0,			-- 処理中
		kDecideLeft = 1,	-- 左太鼓決定（1から変えないこと）
		kDecideRight = 2,	-- 右太鼓決定（2から変えないこと）
		kDecideWait = 3,	-- 決定待ち
		kDecideYes = 4,		-- 「はい」決定
		kCancel = -1,		-- 使わない決定
	},
	-- 選択肢の定数
	EnumSelect = {
		kLeft = 1,
		kCenter = 2,
		kRight = 3,
		kYes = 4,
		kNo = 5,
	},

	load_seq_ = 0,
	action_flag_ = false,
	ret_reserve_ = 0,
	contents_name_ = "",
	bg_name_ = "",
	id_str_ = "",
	is_player_select_ = true,

	Init = function(this,InstanceName)
		this.instance_name_ = InstanceName
		this.contents_name_ = ""
		this.bg_name_ = ""
	end,
	-- ロードムービー系
	LoadMovie = function(this)
		Lumen.LoadMovie("lumen/000_default/entry/qr_entry",this.instance_name_)
		this.load_seq_ = 1
	end,
	Loading = function(this)
		-- ロードムービーの終了チェック
		if (Lumen.IsLoadMovieFinish() == true) then
			-- 一度メインのムービークリップのロード終了を待つ
			if(this.load_seq_ == 1) then
				-- ムービークリップ取得
				this.mc_ = Lumen.GetMovieClip(this.instance_name_,true)
				this.load_seq_ = 2
			elseif(this.load_seq_ == 2) then
				return true
			end
		end
		return false
	end,
	LoadContents = function(this,fileName,bgFileName)
		if(this.contents_name_ ~= fileName) then
			this.contents_name_ = fileName
			if(this.contents_name_ ~= "") then
				this.mc_.main_instance:LoadMovie("lumen/"..this.contents_name_,"contents_instance")
			end
		end
		if(this.bg_name_ ~= bgFileName) then
			this.bg_name_ = bgFileName
			if(this.bg_name_ ~= "") then
				this.mc_.main_instance:LoadMovie("lumen/"..this.bg_name_,"bg_instance")
			end
		end
	end,
	LoadingContents = function(this)
		if (Lumen.IsLoadMovieFinish() == true) then
			return true
		end
		return false
	end,
	-- ＱＲの文字列ID設定
	SetupIDString = function(this,id)
		this.id_str_ = id
	end,
	-- 見出し設定
	SetupTitle = function(this)
		this.mc_.main_instance.qr_title_instance.qr_title_text_instnce:SetText("text_qr_title","qr_title_"..this.id_str_)

		-- 今選択しているカーソル位置で分岐
		local checkPlayer = 0
		if(this.select_ == this.EnumSelect.kRight) then
			checkPlayer = 1
		end

		local userType = PlayDataManager.GetUserType(checkPlayer)
		if(userType == UserType.kCard) then
			this.mc_.main_instance.qr_title_instance.qr_title_text_instnce:SetText("text_qr_title_sub","qr_taikoselect_title_sub2_"..this.id_str_)
		else
			this.mc_.main_instance.qr_title_instance.qr_title_text_instnce:SetText("text_qr_title_sub","qr_taikoselect_title_sub_"..this.id_str_)
		end
	end,
	-- プレイヤー選択か設定
	SetupPlayerSelect = function(this,flag)
		this.is_player_select_ = flag
	end,
	-- 初期化
	Setup = function(this)
		if (Lumen.IsLoadMovieFinish() == true) then

			-- テキスト設定
			this.mc_.main_instance:SetText("p1_instance","text_message","left")
			this.mc_.main_instance:SetText("p2_instance","text_message","right")
			this.mc_.main_instance:SetText("nouse_instance","text_message","no_use_taiko")
			this.mc_.main_instance:SetText("yes_instance","text_message","yes_use_taiko")
			this.mc_.main_instance:SetText("no_instance","text_message","no_use_taiko")

			this.mc_.main_instance.info_instance:SetText("new_msg_instance","text_message","new_card_warning")
			this.mc_.main_instance.info_instance:SetTextBorderColor("new_msg_instance","text_message",0xffffff)

			this.mc_.main_instance.guide_instance.select_instance:SetText("text_guide_instance","text_guide","select")
			this.mc_.main_instance.guide_instance.decide_instance:SetText("text_guide_instance","text_guide","decide")

			this.mc_.main_instance:SetText("no_p1_instance","text_message","taikoselect_error_left")
			this.mc_.main_instance:SetText("no_p2_instance","text_message","taikoselect_error_right")

			this.mc_.main_instance.qr_title_instance.qr_title_text_instnce:SetText("text_qr_title","")
			this.mc_.main_instance.qr_title_instance.qr_title_text_instnce:SetText("text_qr_title_sub","")

			this.don_mc_ = {this.mc_.main_instance.info_instance.don1p,this.mc_.main_instance.info_instance.don2p}

			this.select_ = this.EnumSelect.kCenter
			this.select_min_ = this.EnumSelect.kLeft
			this.select_max_ = this.EnumSelect.kRight
		end
	end,
	-- 表示ON/OFF
	SetVisible = function(this,flag)
		this.mc_:SetVisible(flag)
	end,
	-- 開始
	Start = function(this,qr_available_1p,qr_available_2p)
		this.action_flag_ = false
		this.ret_reserve_ = this.EnumReturn.kDoing
		this.action_mc_ = this.mc_.main_instance.blink_left_instance

		this.use_don_id_ = 0

		this.mc_.main_instance.qr_title_instance:SetVisible(true)

		-- ＱＲを設定できない側は選択肢を見えなくする
		if(this.is_player_select_ == true) then
			-- プレイヤー選択させる
			this.mc_.main_instance:SetText("text_message","whitch_taiko")

			-- カーソル位置など
			this.select_ = this.EnumSelect.kCenter
			this.select_min_ = this.EnumSelect.kLeft
			this.select_max_ = this.EnumSelect.kRight

			if(qr_available_1p == false) then
				this.mc_.main_instance.p1_instance:SetVisible(false)
				this.mc_.main_instance.no_p1_instance:SetVisible(true)
				this.mc_.main_instance.blink_left_instance:SetVisible(false)
				this.select_min_ = this.EnumSelect.kCenter
			else
				this.mc_.main_instance.p1_instance:SetVisible(true)
				this.mc_.main_instance.no_p1_instance:SetVisible(false)
				this.mc_.main_instance.blink_left_instance:SetVisible(true)
			end
			if(qr_available_2p == false) then
				this.mc_.main_instance.p2_instance:SetVisible(false)
				this.mc_.main_instance.no_p2_instance:SetVisible(true)
				this.mc_.main_instance.blink_right_instance:SetVisible(false)
				this.select_max_ = this.EnumSelect.kCenter
			else
				this.mc_.main_instance.p2_instance:SetVisible(true)
				this.mc_.main_instance.no_p2_instance:SetVisible(false)
				this.mc_.main_instance.blink_right_instance:SetVisible(true)
			end
		else
			-- 「はい」「いいえ」のみ
			this.mc_.main_instance:SetText("text_message","ask_use_qr")

			-- カーソル位置など
			this.select_ = this.EnumSelect.kNo
			this.select_min_ = this.EnumSelect.kYes
			this.select_max_ = this.EnumSelect.kNo
		end

		this:SelectCursor()

		-- どんちゃんは使わない、というか使えません。ＱＲの太鼓選択時点では既に３Ｄどんちゃんを２体使っている可能性があるので。
		-- （todo）３体出せるようになったら考える。
		this.don_mc_[1]:SetVisible(false)
		this.don_mc_[2]:SetVisible(false)
		Don.PauseAnimation(0,true)
		Don.PauseAnimation(1,true)

		-- 既存プレイヤーの分しか使わない
		this.mc_.main_instance.info_instance:GotoAndStop("player")
--		this.mc_.main_instance.info_instance:GotoAndStop("newcard")

		-- ガイド開始
		this.mc_.main_instance.guide_instance:GotoAndPlay("fade_in")

		-- 子開始
		if(this.contents_name_ == "") then
			this.mc_.main_instance.contents_instance:SetVisible(false)
		else
			this.mc_.main_instance.contents_instance:SetVisible(true)
			this.mc_.main_instance.contents_instance:GotoAndPlay("in")
			this.mc_.main_instance.contents_instance.main_instance:GotoAndStop("1p")
			this.mc_.main_instance.contents_instance.main_instance.contents_1p_instance:GotoAndPlay("wait")
		end
		if(this.bg_name_ == "") then
			this.mc_.main_instance.bg_instance:SetVisible(false)
		else
			this.mc_.main_instance.bg_instance:SetVisible(true)
			this.mc_.main_instance.bg_instance:Play()
		end

		-- タイトル設定
		this:SetupTitle()

		-- ウィンドウ開始
		this.mc_:GotoAndPlay("in")
	end,
	-- 終了
	Finish = function(this)
		this.mc_:GotoAndPlay("out")
		-- 立ち絵
		if(this.contents_name_ ~= "") then
			this.mc_.main_instance.contents_instance:GotoAndPlay("out")
		end
	end,

	-- 時間切れ
	TimeUp = function(this)
		-- カーソルをキャンセルに移動させる
		if(this.is_player_select_ == true) then
			this.select_ = this.EnumSelect.kCenter
		else
			this.select_ = this.EnumSelect.kNo
		end
		this:SelectCursor()

		this:Cancel()
	end,
	-- キャンセル
	Cancel = function(this)
		-- ＳＥ「キャンセル」
		TSound:Play("se_common_v12a","primal_cancel_c")

		if(this.is_player_select_ == true) then
			-- カーソルアニメ
			this.mc_.main_instance.center_cursor_instance:GotoAndPlay("decide")

			-- 点滅
			this.mc_.main_instance.blink_center_instance:GotoAndPlay("decide")
			this.action_mc_ = this.mc_.main_instance.blink_center_instance
		else
			-- カーソルアニメ
			this.mc_.main_instance.no_cursor_instance:GotoAndPlay("decide")

			-- 点滅
			this.mc_.main_instance.blink_no_instance:GotoAndPlay("decide")
			this.action_mc_ = this.mc_.main_instance.blink_no_instance
		end
		this.action_flag_ = true

		this.ret_reserve_ = this.EnumReturn.kCancel
	end,

	-- 更新
	Update = function(this)
		local ret_code = 0

		if(this.action_flag_ == true) then
			if(this.action_mc_:IsPlay() == false) then
				return this.ret_reserve_
			end
			return this.EnumReturn.kDecideWait
		end

		if(Input.GetTrigger(Input.ALLPLAYER_RIGHT) == true) then
			if(this.select_ < this.select_max_) then
				this.select_ = this.select_ + 1
				this:SelectCursor()

				if(this.select_ == this.EnumSelect.kRight) then
					-- タイトル設定
					this:SetupTitle()
				end

				-- ＳＥ「小かっ（中央）」
				TSound:Play("se_common_v12a","katsu_c")
			end
		end
		if(Input.GetTrigger(Input.ALLPLAYER_LEFT) == true) then
			if(this.select_ > this.select_min_) then
				this.select_ = this.select_ - 1
				this:SelectCursor()

				if(this.select_ == this.EnumSelect.kLeft) then
					-- タイトル設定
					this:SetupTitle()
				end

				-- ＳＥ「小かっ（中央）」
				TSound:Play("se_common_v12a","katsu_c")
			end
		end
		if((Input.GetTrigger(Input.ALLPLAYER_OK) == true) or (Input.GetTrigger(Input.ALLPLAYER_CANCEL) == true)) then
			if(this.select_ == this.EnumSelect.kLeft) then
				-- ＳＥ「小どん（中央）」
				TSound:Play("se_common_v12a","don_c")

				-- カーソルアニメ
				this.mc_.main_instance.p1_cursor_instance:GotoAndPlay("decide")

				-- 点滅
				this.mc_.main_instance.blink_left_instance:GotoAndPlay("decide")
				this.action_mc_ = this.mc_.main_instance.blink_left_instance
				this.action_flag_ = true

				-- 立ち絵
				if(this.contents_name_ ~= "") then
					this.mc_.main_instance.contents_instance.main_instance.contents_1p_instance:GotoAndPlay("success")
				end

				this.ret_reserve_ = this.EnumReturn.kDecideLeft
			end
			if((this.select_ == this.EnumSelect.kCenter) or (this.select_ == this.EnumSelect.kNo)) then
				this:Cancel()
			end
			if(this.select_ == this.EnumSelect.kRight) then
				-- ＳＥ「小どん（中央）」
				TSound:Play("se_common_v12a","don_c")

				-- カーソルアニメ
				this.mc_.main_instance.p2_cursor_instance:GotoAndPlay("decide")

				-- 点滅
				this.mc_.main_instance.blink_right_instance:GotoAndPlay("decide")
				this.action_mc_ = this.mc_.main_instance.blink_right_instance
				this.action_flag_ = true

				-- 立ち絵
				if(this.contents_name_ ~= "") then
					this.mc_.main_instance.contents_instance.main_instance.contents_1p_instance:GotoAndPlay("success")
				end

				this.ret_reserve_ = this.EnumReturn.kDecideRight
			end
			if(this.select_ == this.EnumSelect.kYes) then
				-- ＳＥ「小どん（中央）」
				TSound:Play("se_common_v12a","don_c")

				-- カーソルアニメ
				this.mc_.main_instance.yes_cursor_instance:GotoAndPlay("decide")

				-- 点滅
				this.mc_.main_instance.blink_yes_instance:GotoAndPlay("decide")
				this.action_mc_ = this.mc_.main_instance.blink_yes_instance
				this.action_flag_ = true

				-- 立ち絵
				if(this.contents_name_ ~= "") then
					this.mc_.main_instance.contents_instance.main_instance.contents_1p_instance:GotoAndPlay("success")
				end

				this.ret_reserve_ = this.EnumReturn.kDecideYes
			end
		end

		return this.EnumReturn.kDoing
	end,
	-- 再生チェック
	IsPlay = function(this)
		return false
--		return this.mc_.credit_instance:IsPlay()
	end,
	-- カーソル表示
	SelectCursor = function(this)
		if(this.select_ == this.EnumSelect.kLeft) then
			this.mc_.main_instance:GotoAndStop("player_left")
		end
		if(this.select_ == this.EnumSelect.kCenter) then
			this.mc_.main_instance:GotoAndStop("not_use")
		end
		if(this.select_ == this.EnumSelect.kRight) then
			this.mc_.main_instance:GotoAndStop("player_right")
		end
		if(this.select_ == this.EnumSelect.kYes) then
			this.mc_.main_instance:GotoAndStop("use_yes")
			this.mc_.main_instance.yes_instance:GotoAndStop("on")
			this.mc_.main_instance.no_instance:GotoAndStop("off")
		end
		if(this.select_ == this.EnumSelect.kNo) then
			this.mc_.main_instance:GotoAndStop("use_no")
			this.mc_.main_instance.yes_instance:GotoAndStop("off")
			this.mc_.main_instance.no_instance:GotoAndStop("on")
		end
	end,
}
