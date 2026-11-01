-- DaniResultSongBase.lua
-- 段位リザルト各曲ベース
DaniResultSongBase = {}

-- 使うクラスを読み込む
require("common.Sound")
require("dani_result.DaniResultSongScore")

-- このクラス
function DaniResultSongBase.New(McInstance)
	return
	{
		-- ムービークリップ
		mainMc_ = McInstance,

		-- インスタンス
		score_ = {},

		-- 変数
		songName_		= "",	-- 曲名
		songNum_		= 0,	-- 曲番号(1st~3rd)
		diff_			= 0,	-- 難易度(かんたん~おに裏)
		diffNum_		= 0,	-- 難易度番号(1~10+)
		counter_ryo_	= 0,	-- 良
		counter_ka_		= 0,	-- 可
		counter_fuka_	= 0,	-- 不可
		counter_renda_	= 0,	-- 連打

		-- フラグ
		isUnreachSong_	= false,	-- 未到達な曲

		isCountUp_		= false,	-- カウントアップ演出中
		isCountUpEnd_	= false,	-- カウントアップ完了
		isUnreach_		= false,	-- 未到達
		isUnreachEnd_	= false,	-- 未到達完了

		SetUp = function(this, songName, songNum, diff, diffNum, ryo, ka, fuka, renda, unreach, isHidden)
			-- 初期設定
			this.songName_		= songName
			this.songNum_		= songNum
			this.diff_			= diff
			this.diffNum_		= diffNum
			this.counter_ryo_	= ryo
			this.counter_ka_	= ka
			this.counter_fuka_	= fuka
			this.counter_renda_	= renda
			this.isUnreachSong_	= unreach

			if(unreach == true and g_arrivalSongCnt_ < songNum)then
				if(isHidden == true)then
					this.songName_ = "hidden"
				end
				this.counter_ryo_	= 0
				this.counter_ka_	= 0
				this.counter_fuka_	= 0
				this.counter_renda_	= 0
			end
		end,

		InitSongData = function(this)
			Debug.PrintString("[DaniResultSongBase] InitSongData")
			-- 曲の情報を設定

			-- テキストの設定
			this.mainMc_.song_board_name_tx_mc:SetText("tx_songname","song_"..this.songName_)				-- 曲名
			this.mainMc_.txt_song_ruby_name:SetText("txt_song_ruby_name","song_detail_"..this.songName_)	-- 曲名ルビ
			this.mainMc_.song_board_unreach_tx_mc:SetText("tx_unreach","dani_result_unreach")				-- 未到達

			-- 曲番号
			if(this.songNum_ == 0) then this.mainMc_.song_board_label_mc:GotoAndStop("1st")
			elseif(this.songNum_ == 1) then this.mainMc_.song_board_label_mc:GotoAndStop("2nd")
			elseif(this.songNum_ == 2) then this.mainMc_.song_board_label_mc:GotoAndStop("3rd")
			end

			-- 難易度
			if(this.diff_ == 0) then this.mainMc_.song_board_diff_mc:GotoAndStop("easy")
			elseif(this.diff_ == 1) then this.mainMc_.song_board_diff_mc:GotoAndStop("normal")
			elseif(this.diff_ == 2) then this.mainMc_.song_board_diff_mc:GotoAndStop("hard")
			elseif(this.diff_ == 3) then this.mainMc_.song_board_diff_mc:GotoAndStop("oni")
			elseif(this.diff_ == 4) then this.mainMc_.song_board_diff_mc:GotoAndStop("ura")
			end

			-- 難易度番号
			this.mainMc_.song_board_diff_num_mc:GotoAndStop("diff_"..this.diffNum_)

			-- フレームの形を番号ごとに設定
			if(this.songNum_ == 0) then this.mainMc_.song_board_base_mc:GotoAndStop("1st")
			elseif(this.songNum_ == 1) then this.mainMc_.song_board_base_mc:GotoAndStop("2nd")
			elseif(this.songNum_ == 2) then this.mainMc_.song_board_base_mc:GotoAndStop("3rd")
			end

			-- フラグ
			this.isCountUp_		= false
			this.isCountUpEnd_	= false
		end,

		InitScoreData = function(this)
			Debug.PrintString("[DaniResultSongBase] InitScoreData")
			-- スコアの情報を設定

			-- 良
			this.score_[1] = DaniResultSongScore.New()
			this.score_[1]:Init(this.mainMc_.count_ryo, 4, this.counter_ryo_)

			-- 可
			this.score_[2] = DaniResultSongScore.New()
			this.score_[2]:Init(this.mainMc_.count_ka, 4, this.counter_ka_)

			-- 不可
			this.score_[3] = DaniResultSongScore.New()
			this.score_[3]:Init(this.mainMc_.count_fuka, 4, this.counter_fuka_)

			-- 連打数
			this.score_[4] = DaniResultSongScore.New()
			this.score_[4]:Init(this.mainMc_.count_renda, 4, this.counter_renda_)
		end,

		StartCountUp = function(this)
			-- カウントアップ開始
			for idx = 1, 4 do
				this.score_[idx]:StartCounter()
			end
			this.isCountUp_ = true
		end,

		UpdateCountUp = function(this)
			-- カウントアップ更新
			local countEnd = 0

			for idx = 1, 4 do
				this.score_[idx]:Update()
				if(this.score_[idx].isEnd_ == true)then
					countEnd = countEnd + 1
				end
			end

			if(countEnd == 4)then
				-- カウントアップ完了判定
				this.isCountUp_		= false
				this.isCountUpEnd_	= true
			end
		end,

		CountSkip = function(this)
			-- スキップ演出時
			for idx = 1, 4 do
				this.score_[idx]:SkipCounter()
			end

			this.isCountUp_		= false
			this.isCountUpEnd_	= true
		end,

		StartUnreach = function(this)
			-- 未到達演出開始
			this.mainMc_:GotoAndPlay("unreach")
		end,

		UpdateUnreach = function(this)
			-- 未到達演出更新
			if(this.mainMc_:IsInCurrentLabelMc("" ,"end_unreach") == true)then
				-- 未到達演出完了判定
				this.isUnreachEnd_ = true
			end
		end,

		UnreachSkip = function(this)
			-- 未到達演出スキップ
			this.mainMc_:GotoAndStop("end_unreach")
		end,
	}
end