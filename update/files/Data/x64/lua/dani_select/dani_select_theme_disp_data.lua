-- 段位選択画面.段位お題の表示物対応クラスLua
-- Masayuki_Teraoka@al.bandainamco.jp

DaniDispData = {}

function DaniDispData.New(iParentMc)
	return
	{	
		
		tbl_DaniKanbanMoveLabel 	  = {"5kyuu", "4kyuu","3kyuu","2kyuu","1kyuu","1dan","2dan","3dan","4dan","5dan",
										"6dan","7dan","8dan","9dan","10dan","11dan","12dan","13dan","14dan","gaiden"},
		
		main_mc_ = iParentMc,
		changeFlag = {false, false, false},
		Init = function(this)
		end,
		
		-- 看板内の曲データ設定.
		SetDaniData = function(this, daniData)
		
			Data = daniData
			
			this:AdaptationDaniData(Data)
		end,
		
		-- 段位データ適応.
		AdaptationDaniData = function(this, daniData)
		
			if (daniData) then
				this:SetDaniLevel(daniData)
				this:SetDaniSongLabel()
				this:SetDaniSongText(daniData)
				this:SetDaniThemeText(daniData)
				this:SetDaniThemeQuota(daniData)
				this:SetDaniIsAvailableQuota(daniData)
				this:SetDaniThemeQuotaText(daniData)
				this:SetDaniSongStar(daniData)
				this:SetDaniSongDiffIcon(daniData)
				this:EraseDispHighScore()
			end
	
		end,
		
		-- 段位のハイスコアの表示更新
		UpdateBestDaniScore = function(this, daniData)
			-- ベストスコアの取得にエラーが出てないなければ表示
			if (daniData and daniData.is_bestscore_error == false) then
				this:SetDaniThemeHighScoreText(daniData)
				this:DispHighScoreAnimation()
				this:SetDaniSongText(daniData)
				--this:StartSongNameChange(daniData)
				daniData.is_bestscore_get = true
			end
		end,
		
		-- 段位の段表示
		SetDaniLevel = function(this, daniData)
			this.main_mc_:GotoAndStop("normal", this.tbl_DaniKanbanMoveLabel[daniData.dani_level])
		end,
		
		-- 楽曲名の指定
		SetDaniSongText = function(this, daniData)
			
			-- 曲名
			this.main_mc_:SetText("normal/set_song_1/txt_song_name","txt_song_name", daniData.song_key[1])
			this.main_mc_:SetText("normal/set_song_2/txt_song_name","txt_song_name", daniData.song_key[2])
			this.main_mc_:SetText("normal/set_song_3/txt_song_name","txt_song_name", daniData.song_key[3])
			
			-- ルビ表記
			this.main_mc_:SetText("normal/set_song_1/txt_song_ruby_name","txt_song_ruby_name", daniData.song_detail_key[1])
			this.main_mc_:SetText("normal/set_song_2/txt_song_ruby_name","txt_song_ruby_name", daniData.song_detail_key[2])
			this.main_mc_:SetText("normal/set_song_3/txt_song_ruby_name","txt_song_ruby_name", daniData.song_detail_key[3])
			
			-- 各楽曲が隠し曲の場合かつプレイヤーが解放していない場合は？？？表記にする
			if (daniData.song_isHidden[1] == true and daniData.song_isOpen[1] == false) then
				this.main_mc_:SetText("normal/set_song_1/txt_song_name","txt_song_name", "dani_select_song_secret")
				this.main_mc_.normal.set_song_1.txt_song_ruby_name:SetVisible(false)
			end
			
			if (daniData.song_isHidden[2] == true and daniData.song_isOpen[2] == false) then
				this.main_mc_:SetText("normal/set_song_2/txt_song_name","txt_song_name", "dani_select_song_secret")
				this.main_mc_.normal.set_song_2.txt_song_ruby_name:SetVisible(false)
			end
			
			if (daniData.song_isHidden[3] == true and daniData.song_isOpen[3] == false) then
				this.main_mc_:SetText("normal/set_song_3/txt_song_name","txt_song_name", "dani_select_song_secret")
				this.main_mc_.normal.set_song_3.txt_song_ruby_name:SetVisible(false)
			end

		end,
		
		
		-- StartSongNameChange = function(this, daniData)
		
			-- if (daniData.arrival_song ~= 0) then
			
				-- if (daniData.song_isHidden[1] == true and daniData.song_isOpen[1] == true) then
					
					-- if (this.changeFlag[1] == false) then
						-- this.main_mc_:GotoAndPlay("normal/set_song_1", "change")
						-- this.changeFlag[1] = true
					-- end
				-- end
				
				-- if (daniData.song_isHidden[2] == true and daniData.song_isOpen[2] == true and this.main_mc_.normal.set_song_2.current_frame <= 10) then
					-- this.main_mc_:GotoAndPlay("normal/set_song_2", "change")
				-- end
				
				-- if (daniData.song_isHidden[3] == true and daniData.song_isOpen[3] == true and this.main_mc_.normal.set_song_3.current_frame <= 10) then
					-- this.main_mc_:GotoAndPlay("normal/set_song_3", "change")
				-- end
				
			-- end
		-- end,
		
		--お題名の指定
		SetDaniThemeText = function(this, daniData)
			
			-- クリア条件タイトル
			this.main_mc_:SetText("normal/txt_clear_label","txt_clear_label", "dani_select_clear_requirement")
			
			-- 魂ゲージ
			this.main_mc_:SetText("normal/set_gauge/txt_name_gauge","txt_name_gauge", "clear_theme_soul_gauge")
			
			-- お題に合わせて表示内容を変える
			for idx = 1, 3 do
				if (daniData.theme_genre[idx + 1] == NormaType.kGoodNum) then
					this.main_mc_:SetText("normal/set_score_"..idx.."/txt_theme_name", "txt_theme_name", "clear_theme_ryo")

				elseif (daniData.theme_genre[idx + 1] == NormaType.kOkNum) then            
					this.main_mc_:SetText("normal/set_score_"..idx.."/txt_theme_name", "txt_theme_name", "clear_theme_ka")
  
				elseif (daniData.theme_genre[idx + 1] == NormaType.kBadNum) then          
					this.main_mc_:SetText("normal/set_score_"..idx.."/txt_theme_name", "txt_theme_name", "clear_theme_fuka")

				elseif (daniData.theme_genre[idx + 1] == NormaType.kMaxComboNum) then         
					this.main_mc_:SetText("normal/set_score_"..idx.."/txt_theme_name", "txt_theme_name", "clear_theme_combo")

				elseif (daniData.theme_genre[idx + 1] == NormaType.kDramrollNum) then        
					this.main_mc_:SetText("normal/set_score_"..idx.."/txt_theme_name", "txt_theme_name", "clear_theme_renda")

				elseif (daniData.theme_genre[idx + 1] == NormaType.kScore) then        
					this.main_mc_:SetText("normal/set_score_"..idx.."/txt_theme_name", "txt_theme_name", "clear_theme_score")

				elseif (daniData.theme_genre[idx + 1] == NormaType.kHitNum) then    
					this.main_mc_:SetText("normal/set_score_"..idx.."/txt_theme_name", "txt_theme_name", "clear_theme_total_hit")

				end
			end
		end,
		
		-- お題の存在有無で表示を切り替える
		SetDaniIsAvailableQuota = function(this, daniData)
			for idx = 1, 3 do
				if (daniData.theme_genre[idx + 1] == NormaType.kNone) then
					this.main_mc_:GotoAndStop("normal/set_score_"..idx, "none")
				end
			end
		end,
		
		-- お題ノルマの表示
		SetDaniThemeQuota = function(this, daniData)
			
			-- お題が3曲通しノルマかどうか
			for idx = 1, 3 do
				-- お題のノルマが3曲それぞれある場合
				if (daniData.theme_is_continuous[idx + 1] == false) then
					this.main_mc_:GotoAndStop("normal/set_score_"..idx, "song_no_3")
					this.main_mc_:GotoAndStop("normal/set_score_"..idx.."/set_theme_1/theme_label", "song_no_1")
					this.main_mc_:GotoAndStop("normal/set_score_"..idx.."/set_theme_2/theme_label", "song_no_2")
					this.main_mc_:GotoAndStop("normal/set_score_"..idx.."/set_theme_3/theme_label", "song_no_3")
				else
				-- お題のノルマが通しの場合
					this.main_mc_:GotoAndStop("normal/set_score_"..idx, "song_no_1")
					this.main_mc_:GotoAndStop("normal/set_score_"..idx.."/set_theme_1/theme_label", "song_total")
				end
			end
		end,

		-- お題ノルマのテキスト表示
		SetDaniThemeQuotaText = function(this, daniData)
			
			-- 魂ゲージのノルマテキスト
			this.main_mc_:SetText("normal/set_gauge/txt_num_border_gauge","txt_num_border_gauge", "requirement_soul_gauge")
			
			for idx = 1, 3 do
				-- お題が可・不可の数の場合 "未満" 表示になる
				if (daniData.theme_genre[idx + 1] == NormaType.kOkNum or daniData.theme_genre[idx + 1] == NormaType.kBadNum) then
					
					this.main_mc_:SetText("normal/set_score_"..idx.."/set_theme_1/txt_need_score","txt_need_score", "requirement_less_than_"..idx.."_1")
					this.main_mc_:SetText("normal/set_score_"..idx.."/set_theme_2/txt_need_score","txt_need_score", "requirement_less_than_"..idx.."_2")
					this.main_mc_:SetText("normal/set_score_"..idx.."/set_theme_3/txt_need_score","txt_need_score", "requirement_less_than_"..idx.."_3")
					
				-- 可・不可以外のお題の場合は "以上" の表記になる
				else
					this.main_mc_:SetText("normal/set_score_"..idx.."/set_theme_1/txt_need_score","txt_need_score", "requirement_or_higher_"..idx.."_1")
					this.main_mc_:SetText("normal/set_score_"..idx.."/set_theme_2/txt_need_score","txt_need_score", "requirement_or_higher_"..idx.."_2")
					this.main_mc_:SetText("normal/set_score_"..idx.."/set_theme_3/txt_need_score","txt_need_score", "requirement_or_higher_"..idx.."_3")

				end
			end
		end,

		-- お題ハイスコアのテキスト表示
		SetDaniThemeHighScoreText = function(this, daniData)
			
			-- 魂ゲージのベストスコア表記
			this.main_mc_:SetText("normal/set_gauge/txt_bestscore_name","txt_bestscore_name", "requirement_best_score")
			this.main_mc_:SetText("normal/set_gauge/txt_bestscore_num","txt_bestscore_num", "requirement_soul_gauge_bestscore")
			
			for idx = 1, 3 do
				-- ベストスコアの文字表示
				this.main_mc_:SetText("normal/set_score_"..idx.."/set_theme_1/txt_name_bestscore","txt_name_bestscore", "requirement_best_score")
				this.main_mc_:SetText("normal/set_score_"..idx.."/set_theme_2/txt_name_bestscore","txt_name_bestscore", "requirement_best_score")
				this.main_mc_:SetText("normal/set_score_"..idx.."/set_theme_3/txt_name_bestscore","txt_name_bestscore", "requirement_best_score")
				
				this.main_mc_:SetText("normal/set_score_"..idx.."/set_theme_1/txt_num_bestscore","txt_num_bestscore", tostring(daniData.bestscore_quota[idx][1]))
				this.main_mc_:SetText("normal/set_score_"..idx.."/set_theme_2/txt_num_bestscore","txt_num_bestscore", tostring(daniData.bestscore_quota[idx][2]))
				this.main_mc_:SetText("normal/set_score_"..idx.."/set_theme_3/txt_num_bestscore","txt_num_bestscore", tostring(daniData.bestscore_quota[idx][3]))
			end
		end,
		
		-- ベストスコアの表示を一旦消す
		EraseDispHighScore = function(this)
		
			this.main_mc_:GotoAndStop("normal/set_gauge", "init")
				
			for idx = 1, 3 do
				this.main_mc_:GotoAndStop("normal/set_score_"..idx.."/set_theme_1", "init")
				this.main_mc_:GotoAndStop("normal/set_score_"..idx.."/set_theme_2", "init")
				this.main_mc_:GotoAndStop("normal/set_score_"..idx.."/set_theme_3", "init")
			end
		end,
		
		-- ベストスコアの表示を開始
		DispHighScoreAnimation = function(this)
			
			if (this.main_mc_.normal.set_gauge.current_frame <= 10) then
				this.main_mc_:GotoAndPlay("normal/set_gauge", "bestscore_on")
			end
			
			for idx = 1, 3 do
				if (this.main_mc_.normal.set_score_1.set_theme_1.current_frame <= 10) then
					this.main_mc_:GotoAndPlay("normal/set_score_1/set_theme_1", "bestscore_on")
				end
				if (this.main_mc_.normal.set_score_1.set_theme_2.current_frame <= 10) then
					this.main_mc_:GotoAndPlay("normal/set_score_1/set_theme_2", "bestscore_on")
				end
				if (this.main_mc_.normal.set_score_1.set_theme_3.current_frame <= 10) then
					this.main_mc_:GotoAndPlay("normal/set_score_1/set_theme_3", "bestscore_on")
				end
				if (this.main_mc_.normal.set_score_2.set_theme_1.current_frame <= 10) then
					this.main_mc_:GotoAndPlay("normal/set_score_2/set_theme_1", "bestscore_on")
				end
				if (this.main_mc_.normal.set_score_2.set_theme_2.current_frame <= 10) then
					this.main_mc_:GotoAndPlay("normal/set_score_2/set_theme_2", "bestscore_on")
				end
				if (this.main_mc_.normal.set_score_2.set_theme_3.current_frame <= 10) then
					this.main_mc_:GotoAndPlay("normal/set_score_2/set_theme_3", "bestscore_on")
				end
				if (this.main_mc_.normal.set_score_3.set_theme_1.current_frame <= 10) then
					this.main_mc_:GotoAndPlay("normal/set_score_3/set_theme_1", "bestscore_on")
				end
				if (this.main_mc_.normal.set_score_3.set_theme_2.current_frame <= 10) then
					this.main_mc_:GotoAndPlay("normal/set_score_3/set_theme_2", "bestscore_on")
				end
				if (this.main_mc_.normal.set_score_3.set_theme_3.current_frame <= 10) then
					this.main_mc_:GotoAndPlay("normal/set_score_3/set_theme_3", "bestscore_on")
				end
			end
		end,
		
		-- 各楽曲の難易度（星の数）の表示
		SetDaniSongStar = function(this, daniData)
		
			this.main_mc_:GotoAndStop("normal/set_song_1/song_diff","diff_"..daniData.song_course_star[1])
			this.main_mc_:GotoAndStop("normal/set_song_2/song_diff","diff_"..daniData.song_course_star[2])
			this.main_mc_:GotoAndStop("normal/set_song_3/song_diff","diff_"..daniData.song_course_star[3])
			
		end,
		
		-- 各楽曲の曲順ラベル
		SetDaniSongLabel = function(this)
		
			this.main_mc_:GotoAndStop("normal/set_song_1/label","song_no_1")
			this.main_mc_:GotoAndStop("normal/set_song_2/label","song_no_2")
			this.main_mc_:GotoAndStop("normal/set_song_3/label","song_no_3")
			
		end,

		-- 各楽曲の難易度のアイコン表示
		SetDaniSongDiffIcon = function(this, daniData)
			
			for idx = 1, 3 do
				if (daniData.song_difficulty[idx] == EnsoLevelType.kEasy + 1) then
					this.main_mc_:GotoAndStop("normal/set_song_"..idx.."/song_diff_icon","easy")
					
				elseif (daniData.song_difficulty[idx] == EnsoLevelType.kNormal + 1) then
					this.main_mc_:GotoAndStop("normal/set_song_"..idx.."/song_diff_icon","normal")
					
				elseif (daniData.song_difficulty[idx] == EnsoLevelType.kHard + 1) then
					this.main_mc_:GotoAndStop("normal/set_song_"..idx.."/song_diff_icon","hard")
				
				elseif (daniData.song_difficulty[idx] == EnsoLevelType.kMania + 1) then
					this.main_mc_:GotoAndStop("normal/set_song_"..idx.."/song_diff_icon","oni")
				
				elseif (daniData.song_difficulty[idx] == EnsoLevelType.kUra + 1) then
					this.main_mc_:GotoAndStop("normal/set_song_"..idx.."/song_diff_icon","ura")
				end
			end
		end,
	}
end

