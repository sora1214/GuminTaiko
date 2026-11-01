-- AI曲選択画面.イベント合計勝利数クラスLua
-- Masayuki_Teraoka@al.bandainamco.jp

AISongSelectEventWinsNumPanel = {}
function AISongSelectEventWinsNumPanel.New(InstanceName_1)
	return
	{
		--　インスタンス名を代入
		instance_name_1 = InstanceName_1,
		
		mc_panel_ = 0,
		
		--　ロード
		LoadMovieEventTotalWinsPanel = function(this)
			local filename = "lumen/000_default/enso_ai/song_select/ai_song_select_win_event_count"
			Lumen.LoadMovie(filename,this.instance_name_1)
		end,
		
		-- セットアップ
		SetupEventTotalWinsPanel = function(this)
			if (Lumen.IsLoadMovieFinish() == true) then
				-- ムービークリップ取得
				this.mc_panel_ 	= Lumen.GetMovieClip(this.instance_name_1,true)
				
				this:SetEventTotalWinsNum()
				this:SetEventNeedWinsNum()
				this:SetEventTextPanel()
				
				-- 非表示にするかどうか
				local is_visible = false
				
				if (is_visible == false) then
					this.mc_panel_:SetVisible(false)
				end
			end		
		end,
		
		-- 合計勝利数をセット
		SetEventTotalWinsNum = function(this)
			
			-- ここに合計勝利数を突っ込む
			local total_event_wins = 0
			
			if (total_event_wins >= 999999) then
				total_event_wins = 999999
			end
			
			this:SetCounter(this.mc_panel_.num_total_wins, total_event_wins, 6)
		end,
		
		-- 次のごほうびまでに必要な勝利数をセット
		SetEventNeedWinsNum = function(this)
			
			-- 次のごほうびがあるかどうか
			local is_nextReward = true
			
			if (is_nextReward == false) then
				this.mc_panel_:GotoAndStop("main","max")
			else
				this.mc_panel_:GotoAndStop("main","normal")
			end
			
			-- ここに次のごほうびに必要な勝利数を突っ込む
			local need_event_wins = 1
			
			if (need_event_wins >= 9999) then
				need_event_wins = 9999
			end

			this:SetCounter(this.mc_panel_.num_next_reward, need_event_wins, 4)
		end,
		
		-- テキスト流し込み
		SetEventTextPanel = function(this)
			this.mc_panel_:SetText("main/text_total_wins", "text_total_wins", "ai_song_select_event_total_wins")
			this.mc_panel_:SetText("main/text_next_reward", "text_next_reward", "ai_song_select_event_need_wins")
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

