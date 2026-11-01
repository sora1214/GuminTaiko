-- バナパス使用確認（使う太鼓選択）
TaikoSelect = {
	-- 戻りの定数的な
	EnumReturn = {
		kDoing = 0,			-- 処理中
		kDecideLeft = 1,	-- 左太鼓決定（1から変えないこと）
		kDecideRight = 2,	-- 右太鼓決定（2から変えないこと）
		kDecideWait = 3,	-- 決定待ち
		kDecideYes = 4,		-- 「はい」決定
		kCancel = -1,		-- 使わない決定
	},

	load_seq_ = 0,
	action_flag_ = false,
	ret_reserve_ = 0,
	don_loaded_ = false,

	Init = function(this,InstanceName)
		this.instance_name_ = InstanceName
	end,
	LoadMovie = function(this)
		Lumen.LoadMovie("lumen/000_default/entry/banapass_entry",this.instance_name_)
		this.load_seq_ = 1
	end,
	Loading = function(this)
		-- ロードムービーの終了チェック
		if (Lumen.IsLoadMovieFinish() == true) then
			-- 一度メインのムービークリップのロード終了を待つ
			if(this.load_seq_ == 1) then
				this.load_seq_ = 2
			elseif(this.load_seq_ == 2) then
				-- ムービークリップ取得
				this.mc_ = Lumen.GetMovieClip(this.instance_name_,true)

				-- ネームプレートの読み込み
				this.name_plate_ = NamePlate.New(this.instance_name_.."/main_instance/info_instance/nameplate_instance")
				this.name_plate_:LoadMovie()

				this.load_seq_ = 3
			elseif(this.load_seq_ == 3) then
				this.load_seq_ = 4
			elseif(this.load_seq_ == 4) then
				return true
			end
		end
		return false
	end,
	-- 初期化
	Setup = function(this)
		if (Lumen.IsLoadMovieFinish() == true) then
--			this.mc_ = Lumen.GetMovieClip(this.instance_name_,true)

			-- テキスト設定
			this.mc_.main_instance:SetText("text_message","whitch_taiko")
			this.mc_.main_instance:SetText("p1_instance","text_message","left")
			this.mc_.main_instance:SetText("p2_instance","text_message","right")
			this.mc_.main_instance:SetText("nouse_instance","text_message","no_use_taiko")
			this.mc_.main_instance.info_instance:SetText("new_msg_instance","text_message","new_card_warning")
			this.mc_.main_instance.info_instance:SetTextBorderColor("new_msg_instance","text_message",0xffffff)

			this.mc_.main_instance.guide_instance.select_instance:SetText("text_guide_instance","text_guide","select")
			this.mc_.main_instance.guide_instance.decide_instance:SetText("text_guide_instance","text_guide","decide")

			this.don_mc_ = {this.mc_.main_instance.info_instance.don1p,this.mc_.main_instance.info_instance.don2p}

			-- ネームプレート
			this.name_plate_:Setup()
			this.name_plate_:SetVisible(false)

			this.user_type_ = {UserType.kNone,UserType.kNone}

			this.select_ = 2
			this.select_max_ = 3
			this.select_min_ = 1
		end
	end,
	-- 表示ON/OFF
	SetVisible = function(this,flag)
		this.mc_:SetVisible(flag)
	end,
	-- 開始
	Start = function(this,user_type_1p,user_type_2p)
		this.user_type_ = {user_type_1p,user_type_2p}

		this.action_flag_ = false
		this.ret_reserve_ = this.EnumReturn.kDoing
		this.action_mc_ = this.mc_.main_instance.blink_left_instance

		this.select_ = 2
		this:SelectCursor()

		this.use_don_id_ = 1

		-- カードユーザーでエントリー済みの側は選択肢を見えなくする
		if(this.user_type_[1] == UserType.kCard) then
			this.mc_.main_instance.p1_instance:SetVisible(false)
			this.mc_.main_instance.blink_left_instance:SetVisible(false)
			this.select_min_ = 2

			this.use_don_id_ = 2
		end
		if(this.user_type_[2] == UserType.kCard) then
			this.mc_.main_instance.p2_instance:SetVisible(false)
			this.mc_.main_instance.blink_right_instance:SetVisible(false)
			this.select_max_ = 2

			this.use_don_id_ = 1
		end

		-- 使うどんちゃんの選択
		-- 2Pを使う場合は以下
		-- -- 1Pがコインエントリーで2Pがエントリーなし
		-- -- 1Pがカードエントリー
		if((this.user_type_[1] == UserType.kCoin) and (this.user_type_[2] == UserType.kNone)) then
			this.use_don_id_ = 2
		end

		-- 使うどんちゃんだけ表示
		if(this.use_don_id_ == 1) then
			this.don_mc_[1]:SetVisible(true)
			this.don_mc_[2]:SetVisible(false)
			Don.PauseAnimation(0,false)
			Don.PauseAnimation(1,true)
		else
			this.don_mc_[1]:SetVisible(false)
			this.don_mc_[2]:SetVisible(true)
			Don.PauseAnimation(0,true)
			Don.PauseAnimation(1,false)
		end

		-- カード種別で表示分岐
		this.card_data_ = PlayDataManager.GetCardReadData()
		if(this.card_data_.is_new_data == true) then
			this.mc_.main_instance.info_instance:GotoAndStop("newcard")

			-- どんちゃん設定
			Don.ChangeDefaultDon((this.use_don_id_ - 1),Don.kType_Don)
		else
			this.mc_.main_instance.info_instance:GotoAndStop("player")

			this.name_plate_:SetVisible(true)
			this.name_plate_:SetPlayerInfoEntry(this.card_data_)

			-- どんちゃん設定
			Don.ChangeDonForCardReadData((this.use_don_id_ - 1))
		end
		this.don_loaded_ = false

		-- 向き合わせておく
		Don.CameraReverse((this.use_don_id_ - 1),false)

		-- ガイド開始
		this.mc_.main_instance.guide_instance:GotoAndPlay("fade_in")

		-- ウィンドウ開始
		this.mc_:GotoAndPlay("in")
	end,
	-- 終了
	Finish = function(this)
		this.mc_:GotoAndPlay("out")
	end,

	-- 時間切れ
	TimeUp = function(this)
		this.select_ = 2
		this:SelectCursor()

		this:Cancel()
	end,
	-- キャンセル
	Cancel = function(this)
		-- ＳＥ「キャンセル」
		TSound:Play("se_common_v12a","primal_cancel_c")

		-- カーソルアニメ
		this.mc_.main_instance.center_cursor_instance:GotoAndPlay("decide")

		-- 点滅
		this.mc_.main_instance.blink_center_instance:GotoAndPlay("decide")
		this.action_mc_ = this.mc_.main_instance.blink_center_instance
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

		-- アニメーションの開始待ち
		if(this.don_loaded_ == false) then
			if(Don.IsLoadedDonAll() == true) then
				this.don_loaded_ = true

				if(this.card_data_.is_new_data == true) then
					-- どんちゃんアニメ
					Don.SetLoopAnimation((this.use_don_id_ - 1),"result_clear_loop",true)
					Don.SetNonLoopAnimation((this.use_don_id_ - 1),"result_clear_loop",false)
				else
					-- どんちゃんアニメ
					Don.SetLoopAnimation((this.use_don_id_ - 1),"result_full_loop",true)
					Don.SetNonLoopAnimation((this.use_don_id_ - 1),"result_full_loop",false)
				end
			end
		end

		if(Input.GetTrigger(Input.ALLPLAYER_RIGHT) == true) then
			if(this.select_ < this.select_max_) then
				this.select_ = this.select_ + 1
				this:SelectCursor()

				-- ＳＥ「小かっ（中央）」
				TSound:Play("se_common_v12a","katsu_c")
			end
		end
		if(Input.GetTrigger(Input.ALLPLAYER_LEFT) == true) then
			if(this.select_ > this.select_min_) then
				this.select_ = this.select_ - 1
				this:SelectCursor()

				-- ＳＥ「小かっ（中央）」
				TSound:Play("se_common_v12a","katsu_c")
			end
		end
		if((Input.GetTrigger(Input.ALLPLAYER_OK) == true) or (Input.GetTrigger(Input.ALLPLAYER_CANCEL) == true)) then
			if(this.select_ == 1) then
				-- ＳＥ「小どん（中央）」
				TSound:Play("se_common_v12a","don_c")

				-- カーソルアニメ
				this.mc_.main_instance.p1_cursor_instance:GotoAndPlay("decide")

				-- 点滅
				this.mc_.main_instance.blink_left_instance:GotoAndPlay("decide")
				this.action_mc_ = this.mc_.main_instance.blink_left_instance
				this.action_flag_ = true

				this.ret_reserve_ = this.EnumReturn.kDecideLeft
			end
			if(this.select_ == 2) then
				this:Cancel()
			end
			if(this.select_ == 3) then
				-- ＳＥ「小どん（中央）」
				TSound:Play("se_common_v12a","don_c")

				-- カーソルアニメ
				this.mc_.main_instance.p2_cursor_instance:GotoAndPlay("decide")

				-- 点滅
				this.mc_.main_instance.blink_right_instance:GotoAndPlay("decide")
				this.action_mc_ = this.mc_.main_instance.blink_right_instance
				this.action_flag_ = true

				this.ret_reserve_ = this.EnumReturn.kDecideRight
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
		if(this.select_ == 1) then
			this.mc_.main_instance:GotoAndStop("player_left")
		end
		if(this.select_ == 2) then
			this.mc_.main_instance:GotoAndStop("not_use")
		end
		if(this.select_ == 3) then
			this.mc_.main_instance:GotoAndStop("player_right")
		end
	end,
}
