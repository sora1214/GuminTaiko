-- クレジット受付
CreditWait = {
	Init = function(this,InstanceName)
		this.instance_name_ = InstanceName
		this.is_decide_ = {false,false}
	end,
	LoadMovie = function(this)
		Lumen.LoadMovie("lumen/000_default/entry/entry_credit",this.instance_name_)
	end,
	-- 初期化
	Setup = function(this)
		if (Lumen.IsLoadMovieFinish() == true) then
			this.mc_ = Lumen.GetMovieClip(this.instance_name_,true)

			this.text_mc_ = {this.mc_.credit_instance.player1_text_instance,this.mc_.credit_instance.player2_text_instance}

			-- テキスト設定
			this.mc_.credit_instance:SetText("player1_text_instance","text_player","credit_play_1p")
			this.mc_.credit_instance:SetText("player2_text_instance","text_player","credit_play_2p")

			this.text_mc_[1]:SetText("text_message_instance","text_credit","credit_rest_1p")
			this.text_mc_[2]:SetText("text_message_instance","text_credit","credit_rest_2p")

			this.text_mc_[1]:SetText("text_message_instance_2","text_credit","credit_rest_1p")
			this.text_mc_[2]:SetText("text_message_instance_2","text_credit","credit_rest_2p")
		end
	end,
	-- 表示ON/OFF
	SetVisible = function(this,flag)
		this.mc_:SetVisible(flag)
	end,
	-- 開始
	Start = function(this)
		this.mc_:Play()
		this.mc_.credit_instance:GotoAndPlay("fade_in")
		this.text_mc_[1]:GotoAndPlay("start")
		this.text_mc_[2]:GotoAndPlay("start")
	end,
	-- 終了
	Finish = function(this)
		this.mc_.credit_instance:GotoAndPlay("fade_out")
	end,
	-- 再生チェック
	IsPlay = function(this)
		return this.mc_.credit_instance:IsPlay()
	end,
	-- 決定
	Decide = function(this,playerId)
		this.text_mc_[playerId]:GotoAndPlay("choose")
		this.is_decide_[playerId] = true
	end,
	IsPlayDecide = function(this)
		for loop_idx = 1,2 do
			if(this.is_decide_[loop_idx] == true) then
				if(this.text_mc_[loop_idx]:IsPlay() == true) then
					return true
				end
			end
		end
		return false
	end,
}
