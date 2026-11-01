-- セッティングの地
SettingBase = {
	Init = function(this,InstanceName)
		this.instance_name_ = InstanceName
	end,
	LoadMovie = function(this)
		Lumen.LoadMovie("lumen/000_default/entry/setting_base",this.instance_name_)
	end,

	LoadStandFla = function(this,plIdx,flaFile)
		this.board_mc_[plIdx]:LoadMovie(flaFile,"stand_chara_instance")
		this.stand_chara_enable_[plIdx] = true
		this.load_seq_stand_ = 1
	end,
	LoadingStandFla = function(this)
		if(Lumen.IsLoadMovieFinish() == true) then
			if(this.load_seq_stand_ == 0) then
				return true
			elseif(this.load_seq_stand_ == 1) then
				this.load_seq_stand_ = 2
			elseif(this.load_seq_stand_ == 2) then
				if(this.stand_chara_enable_[1] == true) then
					this.stand_chara_[1] = this.board_mc_[1].stand_chara_instance
					this.stand_chara_[1]:SetVisible(false)
					this.stand_chara_[1]:GotoAndStop("keep")
					this.stand_chara_[1].main_instance:GotoAndStop("1p")
				end
				if(this.stand_chara_enable_[2] == true) then
					this.stand_chara_[2] = this.board_mc_[2].stand_chara_instance
					this.stand_chara_[2]:SetVisible(false)
					this.stand_chara_[2]:GotoAndStop("keep")
					this.stand_chara_[2].main_instance:GotoAndStop("2p")
				end
				this.load_seq_stand_ = 0
				return true
			end
		end
		return false
	end,
	DisableStandChara = function(this,plIdx)
		this.stand_chara_enable_[plIdx] = false
	end,

	-- 初期化
	Setup = function(this)
		if (Lumen.IsLoadMovieFinish() == true) then
			this.mc_ = Lumen.GetMovieClip(this.instance_name_,true)
			this.base_mc_ = {}
			this.base_mc_[1] = this.mc_.settingbase_1p_instance
			this.base_mc_[2] = this.mc_.settingbase_2p_instance
			this.base_mc_[1]:Stop()
			this.base_mc_[2]:Stop()

			this.board_mc_ = {}
			this.board_mc_[1] = this.base_mc_[1].board_instance
			this.board_mc_[2] = this.base_mc_[2].board_instance
			this.board_mc_[1]:Stop()
			this.board_mc_[2]:Stop()

			this.don_mc_ = {}
			this.don_mc_[1] = this.board_mc_[1].don1p
			this.don_mc_[2] = this.board_mc_[2].don2p
			this.don_mc_[1]:Stop()
			this.don_mc_[2]:Stop()
			this.don_mc_[1]:SetVisible(false)
			this.don_mc_[2]:SetVisible(false)

			this.stand_chara_ = {}
			this.stand_chara_enable_ = {false,false}

			this.message_mc_ = {}

			-- ムービークリップ構築
			for loop_idx = 1,2 do
				-- ムービークリップ取得、初期化
				this.message_mc_[loop_idx] = this.board_mc_[loop_idx].message_instance
				this.message_mc_[loop_idx]:SetText("text_message_instance","text_message","wait_a_minutes")
				this.message_mc_[loop_idx]:Stop()
			end

			this.wait_flag_ = {false,false}
			this.work_counter_ = 0

			this.player_num_ = 1

			this.load_seq_stand_ = 0
		end
	end,
	-- プレイヤー数設定
	SetPlayerNum = function(this,playerNum)
		this.player_num_ = playerNum
	end,
	-- 表示ON/OFF
	SetVisible = function(this,flag)
		this.mc_:SetVisible(flag)
	end,
	-- 開始
	Start = function(this,plIdx)
		this.base_mc_[plIdx]:GotoAndPlay("fade_in")

		Don.SetLoopAnimation((plIdx - 1),"normal",true)

		if(this.stand_chara_enable_[plIdx] == true) then
			this.stand_chara_[plIdx]:GotoAndPlay("contents_"..plIdx.."p_instance","wait")
		end
	end,
	-- ちょっと待ってね
	DispWait = function(this,plIdx,flag)
		if(flag == true) then
			this.message_mc_[plIdx]:GotoAndPlay("fade_in")
		else
			this.message_mc_[plIdx]:GotoAndStop("init")
		end
	end,
	DispDon = function(this,plIdx,flag)
		this.don_mc_[plIdx]:SetVisible(flag)

		if(this.stand_chara_enable_[plIdx] == true) then
			this.stand_chara_[plIdx]:SetVisible(flag)
		end
	end,

	StartWait = function(this,plIdx,decideFlg)
		this:DispWait(plIdx,true)
		if(decideFlg == true) then
			-- どんちゃんアニメ
			Don.SetNonLoopAnimation((plIdx - 1),"full_gage",true)
			this.don_mc_[plIdx]:GotoAndPlay("select")

			this.work_counter_ = 0
			this.wait_flag_[plIdx] = true
		else
			this:PlayWaitAnime(plIdx)

			this.work_counter_ = 0
			this.wait_flag_[plIdx] = false
		end
	end,
	UpdateWait = function(this,plIdx)
		if(this.wait_flag_[plIdx] == true) then
			this.work_counter_ = this.work_counter_ + 1
			if(this.work_counter_ > (Common.FPS * 1.0)) then
				if(this.don_mc_[plIdx]:IsPlay() == false) then
					this:PlayWaitAnime(plIdx)

					this.wait_flag_[plIdx] = false
				end
			end
		end
	end,
	-- 待機モーションの再生
	PlayWaitAnime = function(this,plIdx)
		-- どんちゃんアニメ
		Don.SetLoopAnimation((plIdx - 1),"result_clear_loop",true)
		Don.SetNonLoopAnimation((plIdx - 1),"result_clear",false)
	end,

	StartSelectFinishAll = function(this)
		for loop_idx = 1,2 do

			-- 決めたボイス
			if(this.player_num_ == 1) then
				TSound:Play("voice_common_v12a","costume_decide_c")
			else
				if(loop_idx == 1) then
					TSound:Play("voice_common_v12a","costume_decide_l")
				else
					TSound:Play("voice_common_v12a","costume_decide_r")
				end
			end

			-- ちょっと待ってねを消す
			this:DispWait(loop_idx,false)

			-- どんちゃんアニメ
			Don.SetLoopAnimation((loop_idx - 1),"select_loop",true)
			Don.SetNonLoopAnimation((loop_idx - 1),"full_combo",true)

			if(this.stand_chara_enable_[loop_idx] == true) then
				this.stand_chara_[loop_idx]:GotoAndPlay("contents_"..loop_idx.."p_instance","decide")
			end
		end
	end,
}

