-- 難易度選択画面.難易度板表示クラスLua
-- Masayuki_Teraoka@al.bandainamco.jp

SongSelectCourseBoard = {}
function SongSelectCourseBoard.New(InstanceName_1)
	return
	{
		mc_name_              = InstanceName_1, -- MCのインスタンス名を代入
		
		course_record_info_1p = {},				--　1P側の譜面ごとの全スコア情報まとめ
		course_record_info_2p = {},				--　2P側の譜面ごとの全スコア情報まとめ
		
		crown_type_1p         = {},				--　1P側の譜面ごとの王冠情報
		crown_type_2p         = {},				--　2P側の譜面ごとの王冠情報
		
		scorerank_type_1p     = {},				--　1P側の譜面ごとのスコアランク情報
		scorerank_type_2p     = {},             --　2P側の譜面ごとのスコアランク情報

		compe_Idx             = 1,
		compe_Bool            = {},
		compe_BoolType        = {},				-- 1=1Pがtrue, 2=2Pがtrue, 3=1Pと2Pがtrue

		course_num            = 0,				--　各難易度(0=かんたん、1=ふつう、2=むずかしい、3=おに、4=うら）
		
		--　段級位ごとのラベル名
		tbl_DaniLavel 	  = {"5kyuu", "4kyuu","3kyuu","2kyuu","1kyuu","1dan","2dan","3dan","4dan","5dan",
							"6dan","7dan","8dan","9dan","10dan","11dan","12dan","13dan","14dan"},
		
		--　難易度のラベル名
		tbl_DaniCourseLevel = {"easy", "normal", "hard", "oni", "ura"},

		-- コース情報の取得
		GetCourseRecordInfo = function(this)
	
			for idx = 1, (EnsoLevelType.kUra + 1) do
				PlayDataManager.SetPlayerHiScoreFromBestScore(0, selectedSongData.song_uniqueId, (idx -1))
				PlayDataManager.SetPlayerHiScoreFromBestScore(1, selectedSongData.song_uniqueId, (idx -1))

				this.course_record_info_1p[idx] = PlayDataManager.GetEnsoRecordInfo(0, selectedSongData.song_uniqueId, (idx -1))
				this.course_record_info_2p[idx] = PlayDataManager.GetEnsoRecordInfo(1, selectedSongData.song_uniqueId, (idx -1))
			end
		end,
		
		-- 難易度板のイニシャライズ
		AllBoardInitialize = function(this, courseNum) 
			this.course_num = courseNum
			
			this:InitCourseBoard(courseNum)
			this:InitCourseStar(courseNum)
			this:InitCourseCrown(courseNum)
			this:SetCourseCrownData(courseNum)
			this:InitCourseScoreRank(courseNum)
			this:SetScoreRankData(courseNum)
			this:InitSupportIcon(courseNum)
			this:InitBranchIcon(courseNum)
			this:SetCompeIconBool(courseNum)
			this:VisibleOffCrownAndScoreRank(courseNum)
		end,
		
		-- うらに切り替えた時
		ChangeUraBoard = function(this)
			this.course_num = 5
			
			-- 切り替えたタイミングで再表示する
			this:InitCourseCrown(this.course_num)
			this:SetCourseCrownData(this.course_num)
			this:InitCourseScoreRank(this.course_num)
			this:SetScoreRankData(this.course_num)
			
			this:SetCompeIconBool(this.course_num)
			this.mc_name_:GotoAndPlay("change_ura")
		end,
		
		-- おにに切り替えた時
		ChangeOniBoard = function(this)
			this.course_num = 4
			
			-- 切り替えたタイミングで再表示する
			this:InitCourseCrown(this.course_num)
			this:SetCourseCrownData(this.course_num)
			this:InitCourseScoreRank(this.course_num)
			this:SetScoreRankData(this.course_num)
			
			this:SetCompeIconBool(this.course_num)
			this.mc_name_:GotoAndPlay("change_oni")
		end,
		
		--　板の初期化
		InitCourseBoard = function(this, courseNum)
			
			if (courseNum == 1) then 
				this.mc_name_:GotoAndStop("diff_background", "easy")
				this.mc_name_:SetText("text_course_title","text_course_title","course_easy")	

			elseif(courseNum == 2) then
				this.mc_name_:GotoAndStop("diff_background", "normal")
				this.mc_name_:SetText("text_course_title","text_course_title","course_normal")	

			elseif(courseNum == 3) then
				this.mc_name_:GotoAndStop("diff_background", "hard")
				this.mc_name_:SetText("text_course_title","text_course_title","course_hard")					
			elseif(courseNum == 4) then
				this.mc_name_:SetText("text_course_title_oni","text_course_title","course_mania")					
				this.mc_name_:SetText("text_course_title_ura","text_course_title","course_ura")					
			end	
			
		end,
		
		--　星の初期化
		InitCourseStar = function(this, courseNum)
			
			if (courseNum == 1) then 
				this.mc_name_:GotoAndStop("diff_"..selectedSongData.course_star[courseNum])
			elseif(courseNum == 2) then
				this.mc_name_:GotoAndStop("diff_"..selectedSongData.course_star[courseNum])
			elseif(courseNum == 3) then
				this.mc_name_:GotoAndStop("diff_"..selectedSongData.course_star[courseNum])
			elseif(courseNum == 4) then
				this.mc_name_:GotoAndStop("board_oni","diff_" ..selectedSongData.course_star[courseNum])
				this.mc_name_:GotoAndStop("board_ura","diff_" ..selectedSongData.course_star[courseNum + 1])
			end
		end,
		
		-- 王冠の初期化(非表示)
		InitCourseCrown = function(this, courseNum)
			
			if (courseNum == 1) then 
				if (is_CardPlayer[1] == false) then this.mc_name_.crown_1p:SetVisible(false) 
				else this.mc_name_.crown_1p:GotoAndStop("none") end
				if (is_CardPlayer[2] == false) then this.mc_name_.crown_2p:SetVisible(false)
				else this.mc_name_.crown_2p:GotoAndStop("none") end
			elseif(courseNum == 2) then
				if (is_CardPlayer[1] == false) then this.mc_name_.crown_1p:SetVisible(false)
				else this.mc_name_.crown_1p:GotoAndStop("none") end
				if (is_CardPlayer[2] == false) then this.mc_name_.crown_2p:SetVisible(false)
				else this.mc_name_.crown_2p:GotoAndStop("none") end
			elseif(courseNum == 3) then
				if (is_CardPlayer[1] == false) then this.mc_name_.crown_1p:SetVisible(false)
				else this.mc_name_.crown_1p:GotoAndStop("none") end
				if (is_CardPlayer[2] == false) then this.mc_name_.crown_2p:SetVisible(false)
				else this.mc_name_.crown_2p:GotoAndStop("none") end
			elseif(courseNum == 4) then
				if (is_CardPlayer[1] == false) then this.mc_name_.board_oni.crown_1p:SetVisible(false)
				else this.mc_name_.board_oni.crown_1p:GotoAndStop("none") end
				if (is_CardPlayer[2] == false) then this.mc_name_.board_oni.crown_2p:SetVisible(false)
				else this.mc_name_.board_oni.crown_2p:GotoAndStop("none") end
				if (is_CardPlayer[1] == false) then this.mc_name_.board_ura.crown_1p:SetVisible(false)
				else this.mc_name_.board_ura.crown_1p:GotoAndStop("none") end
				if (is_CardPlayer[2] == false) then this.mc_name_.board_ura.crown_2p:SetVisible(false)
				else this.mc_name_.board_ura.crown_2p:GotoAndStop("none") end

			end	
		end,
		
		-- 王冠の種類の検索&セット
		SearchSetCrown = function(this, courseNum)
			for idx = 1, 3 do
				if (idx == this.crown_type_1p[courseNum] and is_CardPlayer[1] == true) then
					if (courseNum == 4) then
						this.mc_name_.board_oni.crown_1p:SetVisible(true)
						this.mc_name_.board_oni.crown_1p:GotoAndStop("badge_crown_"..idx)
					elseif (courseNum == 5) then
						this.mc_name_.board_ura.crown_1p:SetVisible(true)
						this.mc_name_.board_ura.crown_1p:GotoAndStop("badge_crown_"..idx)
					else
						this.mc_name_.crown_1p:SetVisible(true)
						this.mc_name_.crown_1p:GotoAndStop("badge_crown_"..idx)
					end
				end
				
				if (idx == this.crown_type_2p[courseNum] and is_CardPlayer[2] == true) then
					if (courseNum == 4) then
						this.mc_name_.board_oni.crown_2p:SetVisible(true)
						this.mc_name_.board_oni.crown_2p:GotoAndStop("badge_crown_"..idx)
					elseif (courseNum == 5) then
						this.mc_name_.board_ura.crown_2p:SetVisible(true)
						this.mc_name_.board_ura.crown_2p:GotoAndStop("badge_crown_"..idx)
					else
						this.mc_name_.crown_2p:SetVisible(true)
						this.mc_name_.crown_2p:GotoAndStop("badge_crown_"..idx)
					end
				end
			end
		end,
		
		-- スコアランクの初期化(非表示)
		InitCourseScoreRank = function(this, courseNum)
			
			if (courseNum == 1) then 
				if (is_CardPlayer[1] == false) then this.mc_name_.rank_1p:SetVisible(false) 
				else this.mc_name_.rank_1p:GotoAndStop("none") end
				if (is_CardPlayer[2] == false) then this.mc_name_.rank_2p:SetVisible(false)
				else this.mc_name_.rank_2p:GotoAndStop("none") end
			elseif(courseNum == 2) then
				if (is_CardPlayer[1] == false) then this.mc_name_.rank_1p:SetVisible(false)
				else this.mc_name_.rank_1p:GotoAndStop("none") end
				if (is_CardPlayer[2] == false) then this.mc_name_.rank_2p:SetVisible(false)
				else this.mc_name_.rank_2p:GotoAndStop("none") end
			elseif(courseNum == 3) then
				if (is_CardPlayer[1] == false) then this.mc_name_.rank_1p:SetVisible(false)
				else this.mc_name_.rank_1p:GotoAndStop("none") end
				if (is_CardPlayer[2] == false) then this.mc_name_.rank_2p:SetVisible(false)
				else this.mc_name_.rank_2p:GotoAndStop("none") end
			elseif(courseNum == 4) then
				if (is_CardPlayer[1] == false) then this.mc_name_.board_oni.rank_1p:SetVisible(false)
				else this.mc_name_.board_oni.rank_1p:GotoAndStop("none") end
				if (is_CardPlayer[2] == false) then this.mc_name_.board_oni.rank_2p:SetVisible(false)
				else this.mc_name_.board_oni.rank_2p:GotoAndStop("none") end
				if (is_CardPlayer[1] == false) then this.mc_name_.board_ura.rank_1p:SetVisible(false)
				else this.mc_name_.board_ura.rank_1p:GotoAndStop("none") end
				if (is_CardPlayer[2] == false) then this.mc_name_.board_ura.rank_2p:SetVisible(false)
				else this.mc_name_.board_ura.rank_2p:GotoAndStop("none") end

			end	
		end,

		-- スコアランクの種類の検索&セット
		SearchSetScoreRank = function(this, courseNum)
			for idx = 1, 7 do
				if (idx == this.scorerank_type_1p[courseNum] and is_CardPlayer[1] == true) then
					
					if (courseNum == 1 and cardPlayerSelectedCourse[1] == 0) then
						this.mc_name_.rank_1p:SetVisible(true)
						this.mc_name_.rank_1p:GotoAndStop("badge_rank_"..idx)
					end
					
					if (courseNum == 2 and cardPlayerSelectedCourse[1] == 1) then
						this.mc_name_.rank_1p:SetVisible(true)
						this.mc_name_.rank_1p:GotoAndStop("badge_rank_"..idx)
					end

					if (courseNum == 3 and cardPlayerSelectedCourse[1] == 2) then
						this.mc_name_.rank_1p:SetVisible(true)
						this.mc_name_.rank_1p:GotoAndStop("badge_rank_"..idx)
					end

					if (courseNum == 4 and cardPlayerSelectedCourse[1] >= 3) then
						this.mc_name_.board_oni.rank_1p:SetVisible(true)
						this.mc_name_.board_oni.rank_1p:GotoAndStop("badge_rank_"..idx)
					end
					
					if (courseNum == 5 and cardPlayerSelectedCourse[1] >= 4) then
						this.mc_name_.board_ura.rank_1p:SetVisible(true)
						this.mc_name_.board_ura.rank_1p:GotoAndStop("badge_rank_"..idx)
					end
				end
				
				
				if (idx == this.scorerank_type_2p[courseNum] and is_CardPlayer[2] == true) then
					if (courseNum == 1 and cardPlayerSelectedCourse[2] == 0) then
						this.mc_name_.rank_2p:SetVisible(true)
						this.mc_name_.rank_2p:GotoAndStop("badge_rank_"..idx)
					end
					
					if (courseNum == 2 and cardPlayerSelectedCourse[2] == 1) then
						this.mc_name_.rank_2p:SetVisible(true)
						this.mc_name_.rank_2p:GotoAndStop("badge_rank_"..idx)
					end

					if (courseNum == 3 and cardPlayerSelectedCourse[2] == 2) then
						this.mc_name_.rank_2p:SetVisible(true)
						this.mc_name_.rank_2p:GotoAndStop("badge_rank_"..idx)
					end

					if (courseNum == 4 and cardPlayerSelectedCourse[2] >= 3) then
						this.mc_name_.board_oni.rank_2p:SetVisible(true)
						this.mc_name_.board_oni.rank_2p:GotoAndStop("badge_rank_"..idx)
					end
					
					if (courseNum == 5 and cardPlayerSelectedCourse[2] >= 4) then
						this.mc_name_.board_ura.rank_2p:SetVisible(true)
						this.mc_name_.board_ura.rank_2p:GotoAndStop("badge_rank_"..idx)
					end
				end
			end
		end,
		
		-- ドンひろで非表示にしている場合は、ここで各表示をオフにする
		VisibleOffCrownAndScoreRank = function(this, courseNum)
		
			if (play_data_[1].user_data.totalRecordInfo.disp_crown_flag == false) then

				if(courseNum == 4) then
					this.mc_name_.board_oni.crown_1p:SetVisible(false)
					this.mc_name_.board_ura.crown_1p:SetVisible(false)
					this.mc_name_.board_oni.rank_1p:SetVisible(false)
					this.mc_name_.board_ura.rank_1p:SetVisible(false)
				else
					this.mc_name_.crown_1p:SetVisible(false)
					this.mc_name_.rank_1p:SetVisible(false)
				end
			end
			
			if (play_data_[2].user_data.totalRecordInfo.disp_crown_flag == false) then
				if(courseNum == 4) then
					this.mc_name_.board_oni.crown_2p:SetVisible(false)
					this.mc_name_.board_ura.crown_2p:SetVisible(false)
					this.mc_name_.board_oni.rank_2p:SetVisible(false)
					this.mc_name_.board_ura.rank_2p:SetVisible(false)
				else
					this.mc_name_.crown_2p:SetVisible(false)
					this.mc_name_.rank_2p:SetVisible(false)
				end
			end
		end,
		
		-- 王冠のセット(カードのみ)
		SetCourseCrownData = function(this, courseNum)
			
			for idx = 1, 5 do
				this.crown_type_1p[idx] = this.course_record_info_1p[idx].crown
				this.crown_type_2p[idx] = this.course_record_info_2p[idx].crown
			end
				
			this:SearchSetCrown(courseNum)
			
			if (courseNum == 4) then this:SearchSetCrown(courseNum + 1) end
			
		end,
		
		-- スコアランクのセット(カードのみ)
		SetScoreRankData = function(this, courseNum)
			
			for idx = 1, 5 do
				this.scorerank_type_1p[idx] = this.course_record_info_1p[idx].scoreRank
				this.scorerank_type_2p[idx] = this.course_record_info_2p[idx].scoreRank
			end
				
			this:SearchSetScoreRank(courseNum)
			
			if (courseNum == 4) then this:SearchSetScoreRank(courseNum + 1) end
			
		end,
		
		--　分岐譜面用アイコンのセット
		InitBranchIcon = function(this, courseNum)
			
			if (courseNum == 1) then 
				if (selectedSongData.is_branch[1] == true) then
					this.mc_name_:GotoAndStop("branch","branch")
					this.mc_name_:SetText("branch/text_course_branch","text_course_branch","courseselect_branch")	
				else this.mc_name_:GotoAndStop("branch","none")
				end
			elseif (courseNum == 2) then 
				if (selectedSongData.is_branch[2] == true) then 
					this.mc_name_:GotoAndStop("branch","branch")
					this.mc_name_:SetText("branch/text_course_branch","text_course_branch","courseselect_branch")	
				else this.mc_name_:GotoAndStop("branch","none")
				end
			elseif (courseNum == 3) then 
				if (selectedSongData.is_branch[3] == true) then 
					this.mc_name_:GotoAndStop("branch","branch")
					this.mc_name_:SetText("branch/text_course_branch","text_course_branch","courseselect_branch")	
				else this.mc_name_:GotoAndStop("branch","none")
				end
			elseif (courseNum == 4) then 
				if (selectedSongData.is_branch[4] == true) then 
					this.mc_name_:GotoAndStop("board_oni/branch_oni","branch")
					this.mc_name_:SetText("branch_oni/text_course_branch_oni","text_course_branch","courseselect_branch")	
				else this.mc_name_:GotoAndStop("board_oni/branch_oni","none")
				end
				if (selectedSongData.is_branch[5] == true) then 
					this.mc_name_:GotoAndStop("board_ura/branch_ura","branch")
					this.mc_name_:SetText("branch_ura/text_course_branch_ura","text_course_branch","courseselect_branch")	
				else this.mc_name_:GotoAndStop("board_ura/branch_ura","none")
				end
			end
		end,
		
		--　パパママサポートのアイコンのセット
		InitSupportIcon = function(this, courseNum)

			if (courseNum == 1 and selectedSongData.is_papamama == true and player_num < 2 and user_setting_Original_data_[1].ensoSkip == 0 and user_setting_Original_data_[2].ensoSkip == 0) then
				this.mc_name_:GotoAndStop("support","support")
				this.mc_name_:SetText("support/text_course_support","text_course_support","courseselect_support")
			elseif(courseNum ~= 4) then
				this.mc_name_:GotoAndStop("support","none")
			end
		end,
		
		-- 公式大会、大会、挑戦状、段位課題曲の表示フラグを設定
		SetCompeIconBool = function(this, courseNum)

			Debug.PrintString("コース : "..courseNum)

			-- 初期値
			idx = 1

			this.compe_Idx = 1

			for i = 1, 4 do
				this.compe_Bool[i] = 0
				this.compe_BoolType[i] = 0
			end

			-- 取得したデータを設定します。
			local isDani			= selectedSongData.is_dani					-- 段位課題曲かどうか
			local isDaniIconDisp	= selectedSongData.is_dani_icon_disp		-- 段位のアイコンを出していいか
			local dani_level		= selectedSongData.dani_level				-- 該当する段位
			local dani_course		= selectedSongData.dani_course				-- 該当する難易度
			
			isOfficial_1	= selectedSongData.is_officialCompe[1][courseNum]	-- 公式大会	1P
			isCompe_1		= selectedSongData.is_userCompe[1][courseNum]		-- 大会		1P
			isVs_1			= selectedSongData.is_challenge[1][courseNum]		-- 挑戦状	1P

			if (is_CardPlayer[1] == false)then
				isOfficial_1 = false
				isCompe_1 = false
				isVs_1 = false
			end

			isOfficial_2	= selectedSongData.is_officialCompe[2][courseNum]	-- 公式大会 2P
			isCompe_2		= selectedSongData.is_userCompe[2][courseNum]		-- 大会		2P
			isVs_2			= selectedSongData.is_challenge[2][courseNum]		-- 挑戦状	2P

			if (is_CardPlayer[2] == false)then
				isOfficial_2 = false
				isCompe_2 = false
				isVs_2 = false
			end

			-- 段位お題
			if(isDani == true and isDaniIconDisp == true and dani_course == courseNum)then
				this.compe_Bool[idx] = 1

				this.compe_BoolType[idx] = 1

				Debug.PrintString("段位課題曲idx : "..idx)
				Debug.PrintString("段位課題曲bool : "..this.compe_Bool[idx])
				Debug.PrintString("段位課題曲type : "..this.compe_BoolType[idx])

				idx = idx + 1
				
			end
			
			-- 段位課題曲がおに裏で各プレイヤーが未開放の時
			if (isDani == true and isDaniIconDisp == true and dani_course == 5) then
				if (selectedSongData.song_isUraOpen[1] == false and selectedSongData.song_isUraOpen[2] == false) then
					if (this.course_num == 4) then
						this.mc_name_.ura_popup:GotoAndStop(this.tbl_DaniLavel[selectedSongData.dani_level])
					else
						this.mc_name_.ura_popup:GotoAndStop("none")
					end
				end
			else
				this.mc_name_.ura_popup:GotoAndStop("none")
			end

			-- 公式大会
			if(isOfficial_1 == true or isOfficial_2 == true)then
				this.compe_Bool[idx] = 2

				if(isOfficial_2 == false)then
					this.compe_BoolType[idx] = 1
				end

				if(isOfficial_1 == false)then
					this.compe_BoolType[idx] = 2
				end

				if(isOfficial_1 == true and isOfficial_2 == true)then
					this.compe_BoolType[idx] = 3
				end

				Debug.PrintString("公式大会idx : "..idx)
				Debug.PrintString("公式大会bool : "..this.compe_Bool[idx])
				Debug.PrintString("公式大会type : "..this.compe_BoolType[idx])

				idx = idx + 1
			end

			
			-- 大会
			if(isCompe_1 == true or isCompe_2 == true)then
				this.compe_Bool[idx] = 3

				if(isCompe_2 == false)then
					this.compe_BoolType[idx] = 1
				end

				if(isCompe_1 == false)then
					this.compe_BoolType[idx] = 2
				end

				if(isCompe_1 == true and isCompe_2 == true)then
					this.compe_BoolType[idx] = 3
				end

				Debug.PrintString("大会idx : "..idx)
				Debug.PrintString("大会bool : "..this.compe_Bool[idx])
				Debug.PrintString("大会type : "..this.compe_BoolType[idx])

				idx = idx + 1
			end

			-- 挑戦状
			if(isVs_1 == true or isVs_2 == true)then
				this.compe_Bool[idx] = 4

				if(isVs_2 == false)then
					this.compe_BoolType[idx] = 1
				end

				if(isVs_1 == false)then
					this.compe_BoolType[idx] = 2
				end

				if(isVs_1 == true and isVs_2 == true)then
					this.compe_BoolType[idx] = 3
				end

				Debug.PrintString("挑戦状idx : "..idx)
				Debug.PrintString("挑戦状bool : "..this.compe_Bool[idx])
				Debug.PrintString("挑戦状type : "..this.compe_BoolType[idx])

				idx = idx + 1
			end

			Debug.PrintString("アイコンの設定 コース : "..courseNum)
			this:SetCompeIcon(this.compe_Bool[this.compe_Idx], this.compe_BoolType[this.compe_Idx])

			this.mc_name_.compe_icon:GotoAndPlay("fade_in")		-- フェードインから開始
		end,

		-- 公式大会、大会、挑戦状の表示
		SetCompeIcon = function(this, num, type)
		
		-- おにとおにうら用のmc対応
		local compeMc = {}
		if (this.course_num == 4) then
			compeMc = this.mc_name_.board_oni
		elseif (this.course_num == 5) then
			compeMc = this.mc_name_.board_ura
		else
			compeMc = this.mc_name_
		end

			-- アイコン無し
			if(num == 0)then
				compeMc.compe_icon.board_com_icon_mc.com_select:GotoAndStop("none")
			end
			
			-- 段位課題情報
			if(num == 1)then
				compeMc.compe_icon.board_com_icon_mc.com_select:GotoAndStop("icon_dani")
				compeMc.compe_icon.board_com_icon_mc.com_select.dani_level:GotoAndStop(this.tbl_DaniLavel[selectedSongData.dani_level])
			end

			-- 公式大会
			if(num == 2)then
				if(type == 1)then
					compeMc.compe_icon.board_com_icon_mc.com_select:GotoAndStop("icon_official_01")
				elseif(type == 2)then
					compeMc.compe_icon.board_com_icon_mc.com_select:GotoAndStop("icon_official_02")
				elseif(type == 3)then
					compeMc.compe_icon.board_com_icon_mc.com_select:GotoAndStop("icon_official_03")
				end
			end

			-- 大会
			if(num == 3)then
				if(type == 1)then
					compeMc.compe_icon.board_com_icon_mc.com_select:GotoAndStop("icon_compe_01")
				elseif(type == 2)then
					compeMc.compe_icon.board_com_icon_mc.com_select:GotoAndStop("icon_compe_02")
				elseif(type == 3)then
					compeMc.compe_icon.board_com_icon_mc.com_select:GotoAndStop("icon_compe_03")
				end
			end
			
			-- 挑戦状
			if(num == 4)then
				if(type == 1)then
					compeMc.compe_icon.board_com_icon_mc.com_select:GotoAndStop("icon_vs_01")
				elseif(type == 2)then
					compeMc.compe_icon.board_com_icon_mc.com_select:GotoAndStop("icon_vs_02")
				elseif(type == 3)then
					compeMc.compe_icon.board_com_icon_mc.com_select:GotoAndStop("icon_vs_03")
				end
			end
		end,

		-- アイコンのアップデート
		UpdateCompeIcon =function(this)

			local compeMc = {}
			if (this.course_num == 4) then
				compeMc = this.mc_name_.board_oni
			elseif (this.course_num == 5) then
				compeMc = this.mc_name_.board_ura
			else
				compeMc = this.mc_name_
			end

			-- フェードアウトが完了したら
			if(compeMc.compe_icon:IsPlay() == false)then
				this.compe_Idx = this.compe_Idx + 1
				--if(this.compe_Idx > #this.compe_Bool)then
				if(this.compe_Bool[this.compe_Idx] == nil or this.compe_Bool[this.compe_Idx] == 0)then
					this.compe_Idx = 1
				end

				-- アイコン変更
				this:SetCompeIcon(this.compe_Bool[this.compe_Idx], this.compe_BoolType[this.compe_Idx])

				-- フェードインから開始
				compeMc.compe_icon:GotoAndPlay("fade_in")		-- フェードインから開始
			else
				-- 待ち
			end
			
		end,
	}
end