-- AiResultBg.lua
-- Aiリザルト画面の背景表示

AiResultBg = {}
function AiResultBg.New(name)
	return
	{	
		name_ = name,
		mc_,			-- このMC
		main_,			-- mainMC
		bgMc_,			-- 動かす背景MC
		
		LoadMovie = function(this)
			-- Lumen.LoadMovie("lumen/000_default/result/result_bg",this.name_)
			Lumen.LoadMovie("lumen/000_default/enso_ai/result/result_ai_bg",this.name_)
		end,
		
		-- 初期化
		Setup = function(this)
			if (Lumen.IsLoadMovieFinish() == true) then
				-- ムービークリップ取得
				this.mc_ = Lumen.GetMovieClip(this.name_,true)
				this.main_ = this.mc_.main_mc
				if(g_result_ == kWin)then
					this.main_:GotoAndStop("bg_win")
					this.main_.bg_win_mc:GotoAndPlay("loop")
				elseif(g_result_ == kLose)then
					this.main_:GotoAndStop("bg_lose")
					this.main_.bg_lose_mc:GotoAndPlay("loop")
				end
			end
		end,

		-- プレイヤー情報設定
		SetPlayerInfo = function(this)
			if(g_entryType_ == 0) then
				this.main_:GotoAndStop("1p_l")
				this.bgMc_ = this.main_:GetChildMc("bg_1p_l",true)
			elseif(g_entryType_ == 1) then
				this.main_:GotoAndStop("1p_r")
				this.bgMc_ = this.main_:GetChildMc("bg_1p_r",true)
			else
				this.main_:GotoAndStop("2p")
				this.bgMc_ = this.main_:GetChildMc("bg_2p",true)
			end
		end,

		--　ノルマクリア成功時の演出を開始
		StartSuccessEffect = function(this)
			if(g_entryType_ ~= 2) then
				this.bgMc_:GotoAndPlay("success")
			else
				str = "success_"
				for idx = 1, 2 do
					if(g_resultType[idx] ~= 0) then
						str = str..idx.."p"
					end
				end
			
				this.bgMc_:GotoAndPlay(str)
			end
		end,		
	}
end

