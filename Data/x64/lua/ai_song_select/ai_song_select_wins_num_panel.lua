-- AI曲選択画面.合計勝利数クラスLua
-- Masayuki_Teraoka@al.bandainamco.jp

AISongSelectWinsNumPanel = {}
function AISongSelectWinsNumPanel.New(InstanceName_1)
	return
	{
		--　インスタンス名を代入
		instance_name_1 = InstanceName_1,
		
		mc_panel_ = 0,
		
		--　ロード
		LoadMovieTotalWinsPanel = function(this)
			local filename = "lumen/000_default/enso_ai/song_select/ai_song_select_win_count"
			Lumen.LoadMovie(filename,this.instance_name_1)
		end,
		
		-- セットアップ
		SetupTotalWinsPanel = function(this)
			if (Lumen.IsLoadMovieFinish() == true) then
				-- ムービークリップ取得
				this.mc_panel_ 	= Lumen.GetMovieClip(this.instance_name_1,true)
				
				this:SetTotalWinsNum()
				this:SetNeedWinsNum()
				this:SetTextPanel()
				
				-- 非表示にするかどうか
				local is_visible = true
				
				if (is_visible == false) then
					this.mc_panel_:SetVisible(false)
				end
				
			end		
		end,
		
		-- 合計勝利数をセット
		SetTotalWinsNum = function(this)
			
			-- ここに合計勝利数を突っ込む
			local total_wins = play_data_.user_data.aiBattleRecordInfo.current_win_num
			
			-- リミット値
			if (total_wins >= 999999) then
				total_wins = 999999
			end
			
			this:SetCounter(this.mc_panel_.num_total_wins, total_wins, 6)
		end,
		
		-- 次のごほうびまでに必要な勝利数をセット
		SetNeedWinsNum = function(this)
			
			-- ここに次のごほうびに必要な勝利数を突っ込む
			local need_wins = nextRewardNeedTotalWins
			
			-- 念のためのリミット値
			if (need_wins >= 9999) then
				need_wins = 9999
			end
			
			if (need_wins == 0) then
				this.mc_panel_:GotoAndStop("main","max")
			else
				this.mc_panel_:GotoAndStop("main","normal")
			end
			
			this:SetCounter(this.mc_panel_.num_next_reward, need_wins, 4)
		end,
		
		-- テキスト流し込み
		SetTextPanel = function(this)
			this.mc_panel_:SetText("main/text_total_wins", "text_total_wins", "ai_song_select_total_wins")
			this.mc_panel_:SetText("main/text_next_reward", "text_next_reward", "ai_song_select_need_wins")
		end,
		
		SetCounter = function(this,target_mc,number,ketamax)
			
			local MaxKeta = this:GetKeta(number)
			
			target_mc:GotoAndStop("n_digit_"..MaxKeta)
			
			local workNum = number
			local ketanum = 0
			local keta = 0
			for idx = 1,ketamax do
				if((workNum > 0) or (idx == 1))then
					ketanum = workNum % 10
					workNum = math.floor((workNum / 10))
					keta = keta + 1

					target_mc["n"..keta.."_ins"]:GotoAndStop("n_"..ketanum)
				end
			end
		end,
		
		-- 数字の桁数を得る(1~9)
		GetKeta = function(this, num)
			if(num <10) then		return 1 end
			if(num <100) then		return 2 end
			if(num <1000) then		return 3 end
			if(num <10000) then 	return 4 end
			if(num <100000)	then	return 5 end
			if(num <1000000) then	return 6 end
			if(num <10000000) then	return 7 end
			if(num <100000000) then return 8 end
			return 9
		end,

	}
end

