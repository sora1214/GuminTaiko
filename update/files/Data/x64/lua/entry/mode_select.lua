require("common.State")
require("entry.ModeSelectBorad")

-- モード選択
ModeSelect = {
	EnumReturn = {kInit = 0,kDoing = 1,kDecide = 2,kFinish = 3,kChangeList = 4},

	mc_name_list_ = {"kanban_8","kanban_6","kanban_4","kanban_2","kanban_1","kanban_3","kanban_5","kanban_7"},
	center_kanban_id_ = 5,

	return_code_ = 0,
	decide_mode_ = GameMode.kEnso,

	entry_enable_ = {false,false},

	state_ = State.New("ModeSelect"),

	board_open_wait_ = 0,

	voice_start_ = false,
	voice_wait_ = 0,

	start_wait_count_ = 0,
	start_stop_count_ = 0,

	Init = function(this,InstanceName)
		this.instance_name_ = InstanceName
		this.mc_ = Lumen.GetMovieClip(this.instance_name_,true)
		this.list_mc_ = this.mc_.mode_select_list_instance

		-- モード選択看板準備
		this.kanban_num_ = 8	-- 常にMAX準備する
		this.kanban_mc_ = {}

		for idx = 1,this.kanban_num_ do
			this.kanban_mc_[idx] = ModeSelectBorad.New(this.instance_name_.."/mode_select_list_instance/"..this.mc_name_list_[idx])
		end

		-- メニューリスト
		this.menu_list_org_ = {GameMode.kEnso}
		this.select_idx_org_ = 1
		this.select_idx_ = 1

		this.menu_list_new_ = {}
		this.select_idx_new_ = 1

		this.highlight_list_ = {}
	end,
	LoadMovie = function(this)
		for idx = 1,this.kanban_num_ do
			this.kanban_mc_[idx]:LoadMovie()
		end
	end,
	Loading = function(this)
		for idx = 1,this.kanban_num_ do
			if(this.kanban_mc_[idx]:Loading() == false) then
				return false
			end
		end
		return true
	end,
	-- 初期化
	Setup = function(this)
		if (Lumen.IsLoadMovieFinish() == true) then
			-- 初期化→モードは内部で決まってる
			for idx = 1,this.kanban_num_ do
				this.kanban_mc_[idx]:Setup()
			end

			this.voice_start_ = false
			this.voice_wait_ = -1

			-- ステートマシン構築
			this:SetupState()
		end
	end,
	-- 表示ON/OFF
	SetVisible = function(this,flag)
		this.mc_:SetVisible(flag)
	end,
	-- アニメ中か
	IsPlayBoard = function(this)
		return this.kanban_mc_[this.center_kanban_id_]:IsPlayBoard()
	end,
	-- 開始
	Start = function(this,playdata_p1,playdata_p2)
		-- メニューのリスト作成
		this.menu_list_new_,this.select_idx_new_ = this:CreateBoardList(playdata_p1,playdata_p2)

		-- 直前メニューと新メニューでの差分をチェック、追加されたメニューは後で光る
		this.highlight_list_ = this:CheckMenuListUpdate(this.menu_list_org_,this.menu_list_new_)

		this.menu_list_org_ = this.menu_list_new_
		this.select_idx_org_ = this.select_idx_new_
		this.select_idx_ = this.select_idx_org_
		this:SetAllBoard()

		-- 各看板の開始
		for key,value in pairs(this.kanban_mc_) do
			value:Start()
		end
		this.kanban_mc_[this.center_kanban_id_]:OpenFirst()

		-- リスト移動
		this.list_mc_:GotoAndPlay("in")

		-- リストの数が複数だったらＳＥならす
--		if(#this.menu_list_org_ > 1) then
--			-- ＳＥ「シュッ」
--			TSound:Play("se_common_v12a","kanban_slidein")
--		end

		this.return_code_ = ModeSelect.EnumReturn.kInit
		this.decide_mode_ = GameMode.kEnso

		this.voice_start_ = false
		this.voice_wait_ = -1

		this.start_wait_count_ = 0
		this.start_stop_count_ = 0
		this.state_:SetState("StartWait")
	end,
	-- 終了
	Finish = function(this)
		for key,value in pairs(this.kanban_mc_) do
			value:Finish()
		end
	end,
	-- 一時非表示
	Stop = function(this)
		-- 表示off
		this:SetVisible(false)
		-- ボイス停止
		for key,value in pairs(this.kanban_mc_) do
			value:StopOpenVoice()
		end

		-- 看板のバナー消す
		this:FinishBanner()
	end,
	-- 決定
	Decide = function(this,playerId)
		-- 処理しない場合
		if(playerId > 0) then
			if(this.entry_enable_[playerId] == false) then
				return
			end
		end

		-- ＳＥ「大どん（中央）」
		TSound:Play("se_common_v12a","don_big")

		-- 決定アニメ
		this.kanban_mc_[this.center_kanban_id_]:Decide()

		this.return_code_ = ModeSelect.EnumReturn.kDecide

		-- 決まったモード
		this.decide_mode_ = this.menu_list_org_[this.select_idx_]

		-- ボイス、決定した
		TSound:Play("voice_common_v12a","glad_c")

		-- ステート遷移
		this.state_:SetState("Decide")
	end,
	-- 時間切れ
	TimeUp = function(this)
		-- Main以外の場合、メニューを整えちゃう
		if(this.state_.state ~= "Main") then
			-- waitへ
			this.list_mc_:GotoAndStop("wait")

			-- 看板の中身設定
			this:SetAllBoard()
			-- メニュー開く
			this.kanban_mc_[this.center_kanban_id_]:On()
		end

		-- 決定処理
		this:Decide(-1)
	end,
	-- カーソル移動
	MoveCursor = function(this,cursor_move)
		-- 処理しない場合
		if(cursor_move == 0) then
			return
		end
		if(cursor_move < 0) then
			if(this.select_idx_ <= 1) then
				return
			end
		else
			if(this.select_idx_ >= #this.menu_list_org_) then
				return
			end
		end

		-- ＳＥ「小かっ（中央）」
		TSound:Play("se_common_v12a","katsu_c")

		this.select_idx_ = this.select_idx_ + cursor_move

		if(cursor_move < 0) then
			-- リスト移動
			this.list_mc_:GotoAndPlay("list_anim_up")

			-- メニュー閉じる
			this.kanban_mc_[this.center_kanban_id_]:Close(false)
		else
			-- カーソルが下がるとき（メニュー全体が上にスクロールするとき）は、看板用MCの位置が下がった状態から始まるので、一度リストを作り直してからリスト移動させる

			-- 看板の中身設定
			this:SetAllBoard()

			-- メニュー閉じる
			this.kanban_mc_[(this.center_kanban_id_ - 1)]:Close(true)

			-- リスト移動
			this.list_mc_:GotoAndPlay("list_anim_down")
		end

		this.state_:SetState("MenuMove")
	end,
	-- 決定したモード取得
	GetDecideMode = function(this)
		return this.decide_mode_
	end,
	-- メニューの数取得
	GetMenuNum = function(this)
		return #this.menu_list_org_
	end,
	-- 看板構成を変更する
	ChangeBoardList = function(this,playdata_p1,playdata_p2)
		-- 新しいメニューのリスト作成
		this.menu_list_new_,this.select_idx_new_ = this:CreateBoardList(playdata_p1,playdata_p2)
		-- 元メニューの初期カーソル位置に戻す
		this.select_idx_ = this.select_idx_org_

		-- リスト移動
		this.list_mc_:GotoAndPlay("outside")

		this.return_code_ = ModeSelect.EnumReturn.kChangeList

		-- ボイス停止
		for key,value in pairs(this.kanban_mc_) do
			value:StopOpenVoice()
		end

		-- 看板のバナー消す
		this:FinishBanner()

		-- ステート遷移
		this.state_:SetState("ChangeList")
	end,
	-- 看板構成が変わるかチェック
	CheckBoardListChange = function(this,playdata_p1,playdata_p2)
		local work_list = {}
		local work_idx = 1

		-- 新しいメニューのリスト作成
		work_list,work_idx = this:CreateBoardList(playdata_p1,playdata_p2)

		-- 今のリストと比較
		-- リストサイズが違う場合はもう構成変わる
		if(#this.menu_list_org_ ~= #work_list) then
			return true
		end

		-- リストの中身確認
		for idx = 1,#this.menu_list_org_ do
			if(this.menu_list_org_[idx] ~= work_list[idx]) then
				return true
			end
		end

		return false
	end,
	-- 看板構成の作成（注：ゲームのモードが増えたらこの中を改造する）
	CreateBoardList = function(this,playdata_p1,playdata_p2)
		local dani_available = Cabinet.DaniDojoAvailable()
		local ai_available = Cabinet.AIBattleAvailable()

		-- 段位を使えるか
		local dani_enable = false
		if(dani_available == true) then
			-- エントリー種別
			-- １Ｐがカード、クレジット有効、２Ｐなし
			if(	((playdata_p1.user_type == UserType.kCard) and (playdata_p1.is_use_credit == true) and (playdata_p2.user_type == UserType.kNone)) or
				((playdata_p2.user_type == UserType.kCard) and (playdata_p2.is_use_credit == true) and (playdata_p1.user_type == UserType.kNone))) then
				dani_enable = true
			end
		end
		-- ＡＩを使えるか
		local ai_enable = false
		if(ai_available == true) then
			-- エントリー種別
			-- １Ｐがカード、クレジット有効、２Ｐなし
			if(	((playdata_p1.user_type == UserType.kCard) and (playdata_p1.is_use_credit == true) and (playdata_p2.user_type == UserType.kNone)) or
				((playdata_p2.user_type == UserType.kCard) and (playdata_p2.is_use_credit == true) and (playdata_p1.user_type == UserType.kNone))) then
				ai_enable = true
			end
		end

		local menu_list = {}
		local select_idx = 1
		local add_idx = 1

		-- リスト構築
		-- まずAI
		if(ai_enable == true) then
			menu_list[add_idx] = GameMode.kAI
			add_idx = add_idx + 1
		end
		-- 演奏ゲームは絶対ある
		select_idx = add_idx
		menu_list[add_idx] = GameMode.kEnso
		add_idx = add_idx + 1
		-- 段位道場
		if(dani_enable == true) then
			menu_list[add_idx] = GameMode.kDani
			add_idx = add_idx + 1
		end

		return menu_list,select_idx
	end,
	-- リストの重複チェック（newlist側に新しく追加されたインデックスのリストを返す）
	CheckMenuListUpdate = function(this,oldlist,newlist)
		local ret_list = {}
		local ret_idx = 1

		for newidx = 1,#newlist do
			local add_flag = true

			for oldidx = 1,#oldlist do
				-- 旧リストの中に存在すれば追加しない
				if(newlist[newidx] == oldlist[oldidx]) then
					add_flag = false
				end
			end
			if(add_flag == true) then
				ret_list[ret_idx] = newidx
				ret_idx = ret_idx + 1
			end
		end

		return ret_list
	end,
	StartVoiceWait = function(this)
		this.voice_start_ = true
		this.voice_wait_ = 2.1 * Common.FPS
	end,
	StartBanner = function(this)
		-- 看板のバナー出す→全部出す
		for idx = 1,this.kanban_num_ do
			this.kanban_mc_[idx]:StartBanner()
		end
	end,
	FinishBanner = function(this)
		-- 看板のバナー消す→全部消す
		for idx = 1,this.kanban_num_ do
			this.kanban_mc_[idx]:FinishBanner()
		end
	end,

	-- 更新
	Update = function(this,entry_enable_p1,entry_enable_p2)
		this.entry_enable_[1] = entry_enable_p1
		this.entry_enable_[2] = entry_enable_p2

-- 2020.04.20 時間で切り替え、やめる
--		if(this.voice_wait_ > 0) then
--			this.voice_wait_ = this.voice_wait_ - 1
--		end

		-- ステート実行
		this.state_:Update()

		for idx = 1,this.kanban_num_ do
			local menu_idx = this.select_idx_ + idx - this.center_kanban_id_
			if(menu_idx > 0) and (menu_idx <= #this.menu_list_org_) then
				this.kanban_mc_[idx]:Update()
			end
		end

		return this.return_code_
	end,

	-- ステートチェック
	CheckState = function(this,iState)
		return this.state_:CheckState(iState)
	end,

	-- 看板の中身を設定する
	SetAllBoard = function(this)

		-- this.menu_list_org_とthis.select_idx_から表示内容を作る
		local disp_list = {}
		for idx = 1,this.kanban_num_ do

			-- ループしないパターン
			local menu_idx = this.select_idx_ + idx - this.center_kanban_id_

			if(menu_idx > 0) and (menu_idx <= #this.menu_list_org_) then
				this.kanban_mc_[idx]:SetVisible(true)
				this.kanban_mc_[idx]:ChangeDisplay(this.menu_list_org_[menu_idx])
				this.kanban_mc_[idx]:Off()
			else
				this.kanban_mc_[idx]:SetVisible(false)
			end
		end

	end,

	SetupState = function(this)
		-- ステートマシンの組み立て
		this.state_.func_["Begin"] = function()
--			this.state_:SetState("StartWait")
		end

		-- 開始後の待ち
		this.state_.func_["StartWait"] = function()
			this.start_wait_count_ = this.start_wait_count_ + 1
			if(this.list_mc_:IsPlay() == false) then
				this.start_stop_count_ = this.start_stop_count_ + 1
			end
			if((this.start_stop_count_ > (Common.FPS * 0.5)) or (this.start_wait_count_ > (Common.FPS * 0.6))) then
				-- ハイライトするメニューがあればハイライト
				if(#this.highlight_list_ >= 1) then
					for idx = 1,#this.highlight_list_ do
						local kanban_idx = this.highlight_list_[idx] - this.select_idx_ + this.center_kanban_id_
						this.kanban_mc_[kanban_idx]:HighLight()
					end
					this.state_:SetState("StartListHighLight")
				else
					this.state_:SetState("StartWaitCountInit")
				end
			end
		end
		this.state_.func_["StartListHighLight"] = function()
			this.start_wait_count_ = this.start_wait_count_ + 1
			for idx = 1,#this.highlight_list_ do
				-- 再生中があれば抜け
				if(this.kanban_mc_[this.highlight_list_[idx]]:IsPlayBoard() == true) then
					return
				end
			end
			this.state_:SetState("StartWaitCountInit")
		end
		this.state_.func_["StartWaitCountInit"] = function()
			this:StartBanner()
			this.state_:SetState("StartWaitCount")
		end
		this.state_.func_["StartWaitCount"] = function()
			this.start_wait_count_ = this.start_wait_count_ + 1
			if(this.start_wait_count_ > (Common.FPS * 1.5)) then
				this.return_code_ = ModeSelect.EnumReturn.kDoing
				this.state_:SetState("Main")
			end
		end

		-- 選択処理
		this.state_.func_["Main"] = function()
--[[
			if(this.board_open_wait_ > 0) then
				this.board_open_wait_ = this.board_open_wait_ - 1
				if(this.board_open_wait_ <= 0) then
					-- メニュー開く
					this.kanban_mc_[this.center_kanban_id_]:Open()
				end
			end
]]

			-- 開いたらボイス再生
			if(this.voice_wait_ == 0) then
				this.kanban_mc_[this.center_kanban_id_]:PlayOpenVoice()
			end

			-- 決定
			if((Input.GetTrigger(Input.PLAYER1_OK) == true) or (Input.GetTrigger(Input.PLAYER1_CANCEL) == true)) then
			-- １Ｐ側ドン
				-- 決定
				this:Decide(1)
			elseif((Input.GetTrigger(Input.PLAYER2_OK) == true) or (Input.GetTrigger(Input.PLAYER2_CANCEL) == true)) then
			-- ２Ｐ側ドン
				-- 決定
				this:Decide(2)
			elseif(Input.GetTrigger(Input.AVAILABLE_LEFT) == true) then
			-- ←
				this:MoveCursor(-1)
			elseif(Input.GetTrigger(Input.AVAILABLE_RIGHT) == true) then
			-- →
				this:MoveCursor(1)
			end
		end

		-- メニュー移動中
		this.state_.func_["MenuMove"] = function()
			if(this.list_mc_:IsPlay() == false) then
				-- waitへ
				this.list_mc_:GotoAndStop("wait")

				-- 看板の中身設定
				this:SetAllBoard()

				-- メニュー移動したらボイス切り替えがはじまる
				this.voice_wait_ = 0

				-- メニュー移動後に看板が開くまでの待ち時間
--				this.board_open_wait_ = Common.FPS * 0.2
				this.board_open_wait_ = 1

				-- すぐ看板開く
				this.kanban_mc_[this.center_kanban_id_]:Open()
				-- 看板開き待ちへ
				this.state_:SetState("BoardOpenWait")

-- ↓看板開き待ちをしない場合はこっち↓
--				this.state_:SetState("Main")
			end
		end

		-- 看板開くまで待つ
		this.state_.func_["BoardOpenWait"] = function()
			if(this.kanban_mc_[this.center_kanban_id_]:IsPlayBoard() == false) then
				-- ボイス鳴らす
				this.kanban_mc_[this.center_kanban_id_]:PlayOpenVoice()

				this.state_:SetState("Main")
			end
		end

		-- 決定
		this.state_.func_["Decide"] = function()
		end

		-- メニュー作り直し
		this.state_.func_["ChangeList"] = function()
			if(this.list_mc_:IsPlay() == false) then
				-- 直前メニューと新メニューでの差分をチェック、追加されたメニューは後で光る
				this.highlight_list_ = this:CheckMenuListUpdate(this.menu_list_org_,this.menu_list_new_)

				this.menu_list_org_ = this.menu_list_new_
				this.select_idx_org_ = this.select_idx_new_
				this.select_idx_ = this.select_idx_org_
				this:SetAllBoard()

				this.kanban_mc_[this.center_kanban_id_]:OpenFirst()

				-- リスト移動
				this.list_mc_:GotoAndPlay("inside")

				-- リストの数が複数だったらＳＥならす
--				if(#this.menu_list_org_ > 1) then
--					-- ＳＥ「シュッ」
--					TSound:Play("se_common_v12a","kanban_slidein")
--				end

				-- ステート遷移
				this.start_wait_count_ = 0
				this.start_stop_count_ = 0
				this.state_:SetState("StartWait")
			end
		end
	end
}
