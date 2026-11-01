require("common.Banner")

-- モード選択看板
ModeSelectBorad = {}
function ModeSelectBorad.New(InstanceName)
	return
	{
		instance_name_ = InstanceName,
		banner_ = Banner.New(InstanceName.."/board_main_instance/banner_instance",false,false,GameMode.kEnso),
		is_open_ = false,
		now_mode_ = GameMode.kEnso,
		is_play_voice_ = false,
		load_seq_ = 0,
		is_banner_start = false,

		LoadMovie = function(this)
			Lumen.LoadMovie("lumen/000_default/entry/mode_select",this.instance_name_)
			this.load_seq_ = 1
		end,
		Loading = function(this)
			-- ロードムービーの終了チェック
			if (Lumen.IsLoadMovieFinish() == true) then
				if(this.load_seq_ == 1) then
					this.load_seq_ = 2
				elseif(this.load_seq_ == 2) then
					-- バナー読み込み
					this.banner_:LoadMovie()
					this.load_seq_ = 3
				elseif(this.load_seq_ == 3) then
					this.load_seq_ = 4
				elseif(this.load_seq_ == 4) then
					return true
				end
			end
			return true
		end,
		Setup = function(this)
			if (Lumen.IsLoadMovieFinish() == true) then
				-- ムービークリップ取得
				this.mc_ = Lumen.GetMovieClip(this.instance_name_,true)
				this.board_mc_ = this.mc_.board_main_instance

				-- バナーの準備
				this.banner_:Setup()
				this.banner_:SetVisible(false)

				this:ChangeDisplay(GameMode.kEnso)
			end
		end,
		-- 表示ON/OFF
		SetVisible = function(this,flag)
			this.mc_:SetVisible(flag)
		end,
		-- はじめる
		Start = function(this)
			this.mc_:GotoAndStop("start")
		end,
		-- 終わらせる
		Finish = function(this)
			this.mc_:GotoAndPlay("finish")
		end,
		-- 開く（メニューに入ったときの最初の開く）
		OpenFirst = function(this)
			this.board_mc_:GotoAndPlay("in")
			this.is_open_ = true
			this.is_play_voice_ = false
		end,
		-- 開く
		Open = function(this)
			if(this.is_open_ == false) then
				this.board_mc_:GotoAndPlay("select_on")
				this.is_open_ = true
				this.is_play_voice_ = false
			end
		end,
		-- 閉じる
		Close = function(this,is_force)
			if((this.is_open_ == true) or (is_force == true)) then
				this.board_mc_:GotoAndPlay("select_off")
				this.is_open_ = false

				-- ボイス消す
				this:StopOpenVoice()
			end
		end,
		-- 開いた状態にする
		On = function(this)
			this.board_mc_:GotoAndStop("on")
			this.is_open_ = true
		end,
		-- 閉じた状態にする
		Off = function(this)
			this.board_mc_:GotoAndStop("off")
			this.is_open_ = false
		end,
		-- 決定アクションする
		Decide = function(this)
			this.board_mc_:GotoAndPlay("choose")
		end,
		-- ハイライトする
		HighLight = function(this)
			this.board_mc_:GotoAndPlay("inside")
		end,
		-- ボード再生中？
		IsPlayBoard = function(this)
			return this.board_mc_:IsPlay()
		end,
		-- 表示切り替え
		ChangeDisplay = function(this,mode)
			this.now_mode_ = mode

			-- モード→内部ラベルの文字列
			-- GameModeが変更されたらここも変わるので要注意
--			local modename_list = {"enso","dani","ai"}
			local modename_list = {}
			modename_list[(GameMode.kEnso + 1)] = "enso"
			modename_list[(GameMode.kDani + 1)] = "dani"
			modename_list[(GameMode.kAI + 1)] = "ai"
			local modestring = modename_list[(this.now_mode_ + 1)]

			-- 背景設定
			this.board_mc_.board_bg_top_instance:GotoAndStop(modestring)
			this.board_mc_.board_bg_center_instance:GotoAndStop(modestring)
			this.board_mc_.board_bg_bottom_instance:GotoAndStop(modestring)

			-- キャラクター設定
			this.board_mc_.board_chara_r_instance:GotoAndStop(modestring)
			this.board_mc_.board_chara_l_instance:GotoAndStop(modestring)

			-- アイコン設定
			if((this.now_mode_ == GameMode.kDani) or (this.now_mode_ == GameMode.kAI)) then
				-- 一人用
				this.board_mc_.board_icon_instance:GotoAndStop("only_1")
			else
				-- なし
				this.board_mc_.board_icon_instance:GotoAndStop("none")
			end

			-- テキスト設定
			this.board_mc_.text_title_instance:GotoAndStop(modestring)
			this.board_mc_.text_title_instance:SetText("text_instance_1","text_title","mode_select_"..modestring)
			this.board_mc_.text_title_instance:SetText("text_instance_2","text_title","mode_select_"..modestring)
			this.board_mc_:SetText("text_info_instance","text_info","mode_select_comment_"..modestring)

			if(this.now_mode_ == GameMode.kDani) then
				this.board_mc_.board_chara_r_instance:SetText("chara_year_instance","text_year","mode_select_dani_sub")
			end

			-- バナー設定
			this.banner_:ChangeGameMode(this.now_mode_)
			if(this.is_banner_start == true) then
				this.banner_:ReStart()
			end
		end,

		Update = function(this)
			this.banner_:Update()
		end,

		-- 開いた時のボイス再生
		PlayOpenVoice = function(this)
			-- 開いているモード
			if(this.is_open_ == true) then
				if(this.is_play_voice_ == false) then
					-- 板の状態チェックする、か？
					if(this.board_mc_:IsPlay() == false) then
						-- 板のモードに応じてボイス再生
						if(this.now_mode_ == GameMode.kEnso) then
							-- ボイス「演奏ゲーム」
							TSound:PlaySlot("voice_entry_v12a","focus_enso_loop",kEntrySoundSlot_CautionVoice2)
						end
						if(this.now_mode_ == GameMode.kDani) then
							-- ボイス「段位道場」
							TSound:PlaySlot("voice_entry_v12a","focus_danidojo_loop",kEntrySoundSlot_CautionVoice2)
						end
						if(this.now_mode_ == GameMode.kAI) then
							-- ボイス「ＡＩ」
							TSound:PlaySlot("voice_entry_v12a","focus_ai_loop",kEntrySoundSlot_CautionVoice2)
						end
						this.is_play_voice_ = true
					end
				end
--			else
--				this.is_play_voice_ = false
			end
		end,
		StopOpenVoice = function(this)
			-- ボイス消す
			TSound:StopSlot(kEntrySoundSlot_CautionVoice2)
			this.is_play_voice_ = false
		end,

		StartBanner = function(this)
			this.is_banner_start = true
			this.banner_:Start()
		end,
		FinishBanner = function(this)
			this.is_banner_start = false
			this.banner_:Finish()
		end,
	}
end

