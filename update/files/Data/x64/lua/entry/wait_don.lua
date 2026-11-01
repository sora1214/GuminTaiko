-- 待ちどん
WaitDon = {
	disp_don_ = {false,false},
	load_seq_ = 0,
	costume_wait_filename = {"",""},
	costume_wait_enable_ = {false,false},
	costume_wait_mc_ = {},
	costume_wait_base_mc_ = {},

	-- 初期化
	Setup = function(this,wait_mc,smoke_mc)
		this.mc_ = wait_mc

		this.don_mc_ = {this.mc_.wait_instance_1,this.mc_.wait_instance_2}
		this.smoke_mc_ = {smoke_mc.smoke_instance_1,smoke_mc.smoke_instance_2}
		this.don_mc_[1]:SetVisible(false)
		this.don_mc_[2]:SetVisible(false)
	end,
	-- ＱＲ用立ち絵の読み込み
	LoadContents = function(this,fileName1P,fileName2P)
		this.costume_wait_filename[1] = fileName1P
		this.costume_wait_filename[2] = fileName2P
		this.costume_wait_enable_[1] = false
		this.costume_wait_enable_[2] = false

		if(fileName1P ~= "") then
			Lumen.LoadMovie("lumen/"..fileName1P,"wait_chara_instance_1")
			this.load_seq_ = 0
		end
		if(fileName2P ~= "") then
			Lumen.LoadMovie("lumen/"..fileName2P,"wait_chara_instance_2")
			this.load_seq_ = 0
		end
	end,
	LoadingContents = function(this)
		if (Lumen.IsLoadMovieFinish() == true) then
			if(this.load_seq_ == 0) then
				this.load_seq_ = 1
			else
				if(this.costume_wait_filename[1] ~= "") then
					this.costume_wait_base_mc_[1] = Lumen.GetMovieClip("wait_chara_instance_1",true)
					this.costume_wait_base_mc_[1]:GotoAndStop("keep")
					this.costume_wait_base_mc_[1].wait_2p_instance:SetVisible(false)
					this.costume_wait_mc_[1] = this.costume_wait_base_mc_[1].wait_1p_instance
					this.costume_wait_mc_[1]:SetVisible(false)

					this.costume_wait_enable_[1] = true
				end
				if(this.costume_wait_filename[2] ~= "") then
					this.costume_wait_base_mc_[2] = Lumen.GetMovieClip("wait_chara_instance_2",true)
					this.costume_wait_base_mc_[2]:GotoAndStop("keep")
					this.costume_wait_base_mc_[2].wait_1p_instance:SetVisible(false)
					this.costume_wait_mc_[2] = this.costume_wait_base_mc_[2].wait_2p_instance
					this.costume_wait_mc_[2]:SetVisible(false)

					this.costume_wait_enable_[2] = true
				end
				return true
			end
		end
		return false
	end,
	-- どんちゃんを出す
	DispOn = function(this,index,isNormal)
		this.disp_don_[index] = true
		this.don_mc_[index]:SetVisible(true)
		if(isNormal == true) then
			this.don_mc_[index]:GotoAndStop("normal")
		else
			this.don_mc_[index]:GotoAndStop("shadow")
		end

		if(this.costume_wait_enable_[index] == true) then
			this.costume_wait_mc_[index]:SetVisible(true)
			if(isNormal == true) then
				this.costume_wait_mc_[index]:GotoAndStop("normal")
			else
				this.costume_wait_mc_[index]:GotoAndStop("shadow")
			end
		end

	end,
	DispOff = function(this,index)
		this.disp_don_[index] = false
		this.don_mc_[index]:SetVisible(false)

		if(this.costume_wait_enable_[index] == true) then
			this.costume_wait_mc_[index]:SetVisible(false)
		end
	end,
	-- 煙出す
	DispSmoke = function(this,playernum,index)
		if(this.disp_don_[index] == true) then
			if(this.smoke_mc_[index]:IsPlay() == false) then
				this.smoke_mc_[index]:GotoAndPlay("smoke_in")

				if(playernum == 1) then
					-- ＳＥ「きせかえ変化（中央）」
					TSound:Play("se_common_v12a","costume_change_c")
				else
					if(index == 1) then
						-- ＳＥ「きせかえ変化（左）」
						TSound:Play("se_common_v12a","costume_change_l")
					else
						-- ＳＥ「きせかえ変化（右）」
						TSound:Play("se_common_v12a","costume_change_r")
					end
				end
			end
		end
	end,
	DispSmokeForced = function(this,playernum,index)
		this.disp_don_[index] = true
		this:DispSmoke(playernum,index)
	end,
}
