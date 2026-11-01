require("entry.costume_select_one")

-- コスチューム選択
CostumeSelect = {
	label_list_ = {"don","cool","cute","joke","choice","collabo_001","collabo_001"},

	Init = function(this,InstanceName)
		this.instance_name_ = InstanceName
	end,
	LoadMovie = function(this)
		Lumen.LoadMovie("lumen/000_default/entry/costume",this.instance_name_)
	end,
	-- 初期化
	Setup = function(this)
		if (Lumen.IsLoadMovieFinish() == true) then
			this.mc_ = Lumen.GetMovieClip(this.instance_name_,true)

			this.cosutumemain_ = {CostumeSelectOnePlayer.New(this.mc_.costume_1p_instance,1),CostumeSelectOnePlayer.New(this.mc_.costume_2p_instance,2)}
			this.cosutumemain_[1]:Setup()
			this.cosutumemain_[2]:Setup()
		end
	end,
	-- 表示ON/OFF
	SetVisible = function(this,flag)
		this.mc_:SetVisible(flag)
	end,
	-- プレイヤー数設定
	SetPlayerNum = function(this,playerNum)
		this.cosutumemain_[1]:SetPlayerNum(playerNum)
		this.cosutumemain_[2]:SetPlayerNum(playerNum)
	end,
	-- 開始
	Start = function(this,plIdx)
		this.cosutumemain_[plIdx]:Start()
	end,
	StartSelect = function(this,plIdx)
		this.cosutumemain_[plIdx]:StartSelect()
	end,
	-- 煙出す
	StartSmoke = function(this,plIdx)
		this.cosutumemain_[plIdx]:StartSmoke()
	end,
	-- 処理済みにする
	SetFinish = function(this,plIdx)
		this.cosutumemain_[plIdx]:SetFinish()
	end,
	TimeUp = function(this,plIdx)
		this.cosutumemain_[plIdx]:TimeUp()
	end,
	-- 更新
	Update = function(this,plIdx,isWaitUpload)
		return this.cosutumemain_[plIdx]:Update(isWaitUpload)
	end,
	UpdateFinish = function(this,plIdx)
		this.cosutumemain_[plIdx]:UpdateFinishState()
	end,
}
