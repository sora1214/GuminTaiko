-- AiPlayAllDebug.lua
-- デバッグ用パラメータの設定

AiPlayAllDebug = {
	-- ダミーデータの設定
	SetDummyData = function(this, index)
		g_maxSongCount_			= 2
		g_isCardUser_			= true					-- カードユーザーか否か
		-- 総合プレイ結果
		this:SetTotal()
	end,

	SetTotal = function(this)
		-- 総合プレイ結果の設定
		Debug.PrintString("SetTotal")
		for i=1,g_maxSongCount_ do
			Debug.PrintString("ループ数 i :"..i)
			g_isAllOnpuEnd_[i]				= true			-- 最後まで演奏したか[4]
			g_totalSectionNum_[i]			= 5				-- 区間数[4]
			g_totalSongName_[i]				= "song_pklets"	-- 曲名[4]
			g_totalDifficulty_[i]			= 2				-- 難易度[4]
			g_totalScoreNum_[i]				= 1234567		-- スコア[4]
			g_totalCrown_[i]				= 2				-- 王冠[4]
			g_totalscoreRank_[i]			= 2				-- スコアランク[4]
			g_totalBestScoreNum_[i]			= 1000000		-- ベスト:スコア[4]
			g_totalBestCrown_[i]			= 1				-- ベスト：王冠[4]
			g_totalBestScoreRank_[i]		= 1				-- ベスト：スコアランク[4]

			g_totalSectionCrown_[i] = {}
			g_totalSectionTotalScore_[i] = {}
			g_totalBestSectionCrown_[i] = {}
			g_totalBestSectionTotalScore_[i] = {}

			for j=1,g_totalSectionNum_[i] do
				Debug.PrintString("ループ数 j :"..j)
				g_totalSectionCrown_[i][j]			= 2			-- 区間：王冠[4][5]
				g_totalSectionTotalScore_[i][j]		= 1234567	-- 区間：スコア[4][5]
				g_totalBestSectionCrown_[i][j]		= 1			-- 区間ベスト：王冠[4][5]
				g_totalBestSectionTotalScore_[i][j]	= 1000000	-- 区間ベスト：スコア[4][5]
			end

			if(i == 3)then
				g_totalScoreNum_[i]				= 2234567		-- スコア[4]
				g_totalCrown_[i]				= 3				-- 王冠[4]
				g_totalscoreRank_[i]			= 3				-- スコアランク[4]

				for j=1,g_totalSectionNum_[i] do
					Debug.PrintString("ループ数 j :"..j)
					g_totalSectionCrown_[i][j]			= 3			-- 区間：王冠[4][5]
					g_totalSectionTotalScore_[i][j]		= 2234567	-- 区間：スコア[4][5]
				end
			end
		end
	end,

	DebugParamPrint = function(this)
		Debug.PrintString("g_entryType_:"..g_entryType_)

		-- 設定によって変更する部分
		g_entryType_ = 0
		for i=1,g_maxSongCount_ do
			Debug.PrintString("---"..i.."曲目のデータ---")
			Debug.PrintString("区間数        ："..g_totalSectionNum_[i])
			Debug.PrintString("曲名          ："..g_totalSongName_[i])
			Debug.PrintString("スコア        ："..g_totalScoreNum_[i])
			Debug.PrintString("王冠          ："..g_totalCrown_[i])
			Debug.PrintString("スコアランク  ："..g_totalscoreRank_[i])
			Debug.PrintString("ベストスコア  ："..g_totalBestScoreNum_[i])
		
			for j=1,g_totalSectionNum_[i] do
				Debug.PrintString("-"..j.."区間目-")
				Debug.PrintString("王冠        ："..g_totalSectionCrown_[i][j])
				Debug.PrintString("スコア      ："..g_totalSectionTotalScore_[i][j])
				Debug.PrintString("ベスト王冠  ："..g_totalBestSectionCrown_[i][j])
				Debug.PrintString("ベストスコア："..g_totalBestSectionTotalScore_[i][j])
			end
		end
	end,
	
	-- デバッグ用の値を設定
	SetUp = function(this, index)
	end
}