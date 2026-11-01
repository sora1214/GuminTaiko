-- イベントトークンの背景素材専用

AiResultEventTokenBg = {}
function AiResultEventTokenBg.New(name)
	return
	{	
		name_ = name,
		mc_,					-- このMC
		player_ = 1,			-- 1pか2pか（右側の太鼓で１人プレイの場合は1pになります。ご注意を）
		event_token_mc_,		-- イベントトークンMC
		event_token_panel_mc_,	-- イベントトークンパネルMC
		event_reward_mc_,		-- イベントごほうびMC

		LoadMovie = function(this)
			Lumen.LoadMovie("lumen/000_default/result/event_token_bg",this.name_)
		end,

		-- 初期化
		Setup = function(this, playerIndex, mc)
			Debug.PrintString("!!!EventTokenBg Setup!!!")
			if (Lumen.IsLoadMovieFinish() == true) then
				-- ムービークリップ取得
				--this.mc_ = Lumen.GetMovieClip(this.name_,true)
				this.mc_ = mc
				this.player_ = playerIndex
				
				if(playerIndex == 1 and (g_entryType_ == 0 or g_entryType_ == 2)) then
					this.mc_:GotoAndStop("use_left")
				else
					this.mc_:GotoAndStop("use_right")
				end
				
				this.event_token_mc_ = this.mc_.event_token_mc
				this.event_token_panel_mc_ = this.event_token_mc_:GetChildMc("event_token_panel",true)
				this.event_reward_mc_ = this.mc_.event_reward_mc
				
				this.event_token_mc_.event_token_panel.text_event_name:SetText("text_eventname1","result_event_1000")
			end
		end,
		
		
		TEST = function(this, num)
			Debug.PrintString("てすと:"..num)
		end,
		
		-- イベントトークンの表示開始指示
		StartDisplayEventToken = function(this)
			this.event_token_mc_:GotoAndPlay("start")
		end,
				
		-- イベントトークンの加算演出開始指示
		StartUpdateEventToken = function(this)
			this.event_token_panel_mc_:GotoAndPlay("update")
			this.event_token_panel_mc_.medal_anime_mc:GotoAndPlay("start")
		end,
		
		-- イベントトークンのカンスト表示指示
		ChangeKanstEventToken = function(this)
			this.event_token_panel_mc_:GotoAndPlay("comp")
		end,
	
		-- イベントトークンの表示終了指示
		EndDisplayEventToken = function(this)
			this.event_token_mc_:GotoAndPlay("end")
		end,
		
		-- イベントごほうびの表示開始指示
		StartDisplayEventReward = function(this)
			this.event_reward_mc_:GotoAndPlay("start")
		end,
		
		-- イベントごほうびの表示終了指示
		EndDisplayEventReward = function(this)
			this.event_reward_mc_:GotoAndPlay("end")
		end,	
	}
end

