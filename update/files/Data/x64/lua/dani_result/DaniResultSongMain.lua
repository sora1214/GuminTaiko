-- DaniResultSongMain.lua
-- 段位リザルト各曲画面
DaniResultSongMain = {}

-- 使うクラスを読み込む
require("common.Sound")
require("common.State")
require("dani_result.DaniResultSongBase")

-- このクラス
function DaniResultSongMain.New()
	return
	{
		-- ムービークリップ
		mainMc_,

		-- 定数
		kWaitTime_		= 0.5*Common.FPS,	-- 待機時間
		kWaitEndTime_	= 30*Common.FPS,	-- 待機終了時間

		-- インスタンス
		board_ = {},			-- 各曲ボード

		-- 変数
		state_ = State.New("DaniResultSongMain"),

		currentTime_ = 0,		-- 時間

		-- 到達数:到達したステージを記録。１～３。

		--フラグ
		isEnd_ = false,
		isSlideInEnd_ = {false, false, false, false},

		Init = function(this)
			-- 全体シーケンス
			Debug.PrintString("[DaniResultSongMain] Init")

			this.state_.func_["Begin"] = function()
				-- 開始
				Debug.PrintString("[DaniResultSongMain] Begin")
				-- LoadMovie

				this.currentTime_	= 0
				this.isEnd_			= false
				this.state_:SetState("Loading")
			end

			this.state_.func_["Loading"] = function()
				-- 読み込み待ち

				if (Lumen.IsLoadMovieFinish() == true) then
					Debug.PrintString("[DaniResultSongMain] Loading Finish")

					-- MovieClip
					this.mainMc_ = Lumen.GetMovieClip("main_mc",true)
					this.mainMc_:GotoAndPlay("dani")
					TSound:Play("se_daniresult_v12e","partial_intro")		-- SE

					-- 設定
					this:SetUpDaniBoard()
					this:SetUpBoard()

					this.state_:SetState("SlideIn")
					return
				end
				Debug.PrintString("[DaniResultSongMain] Loading Wait...")
			end

			this.state_.func_["SlideIn"] = function()
				-- スライドイン

				if(InputDon() == true)then
					-- スキップ処理
					Debug.PrintString("[DaniResultSongMain] CountUp Finish")
					this.state_:SetState("Skip")
					return
				end

				this:SlideInSE()

				if(this.mainMc_:IsInCurrentLabelMc("" ,"end_song") == true)then
					Debug.PrintString("[DaniResultSongMain] SlideIn Finish")

					-- カウントアップ開始
					--for idx = 1, 3 do
					--	this.board_[idx]:StartCountUp()
					--end
					--this.state_:SetState("CountUp")
					
					this.state_:SetState("Wait")
				end
			end

			this.state_.func_["CountUp"] = function()
				-- カウントアップ

				if(InputDon() == true)then
					-- スキップ処理
					Debug.PrintString("[DaniResultSongMain] CountUp Finish")
					this.state_:SetState("Skip")
					return
				end

				if(this.board_[1].isCountUpEnd_ and this.board_[2].isCountUpEnd_ and this.board_[3].isCountUpEnd_)then
					-- カウントアップ完了
					Debug.PrintString("[DaniResultSongMain] CountUp Finish")
					this.state_:SetState("UnreachStart")
					return
				end

				-- カウントアップ更新
				for idx = 1, 3 do
					if(this.board_[idx].isUnreachSong_ == true)then
						this.board_[idx]:CountSkip()
					else
						this.board_[idx]:UpdateCountUp()
					end
				end
			end
			
			this.state_.func_["UnreachStart"] = function()
				-- 未到達開始
				for idx = 1, 3 do
					if(this.board_[idx].isUnreachSong_ == true)then
						-- 未到達フラグが立っている場合
						this.board_[idx]:StartUnreach()
					end
				end

				this.state_:SetState("UnreachUpdate")
			end

			this.state_.func_["UnreachUpdate"] = function()
				-- 未到達更新
			
				if(InputDon() == true)then
					-- スキップ処理
					Debug.PrintString("[DaniResultSongMain] CountUp Finish")
					this.state_:SetState("Skip")
					return
				end
			
				-- 未到達更新
				local count = 0
				for idx = 1, 3 do
					if(this.board_[idx].isUnreachSong_ == true)then
						-- 未到達フラグが立っている場合
						this.board_[idx]:UpdateUnreach()
			
						if(this.board_[idx].isUnreachEnd_ == true)then
							-- 未到達更新完了
							count = count+1
						end
					else
						-- 未到達フラグが立っていない場合
						count = count+1
					end
				end
			
				if(count == 3)then
					-- すべての未到達演出完了
					Debug.PrintString("[DaniResultSongMain] CountUp Finish")
					this.state_:SetState("Wait")
				end
			end

			this.state_.func_["Skip"] = function()
				-- スキップ処理
				this.mainMc_:GotoAndStop("end_song")

				for idx = 1, 3 do
					this.board_[idx]:CountSkip()
					if(this.board_[idx].isUnreachSong_ == true)then
						this.board_[idx]:UnreachSkip()
					end
				end
				this.state_:SetState("Wait")
			end

			this.state_.func_["Wait"] = function()
				-- 待機
				this.currentTime_ = this.currentTime_ + 1
				if(this.currentTime_ < this.kWaitTime_)then
					-- スコアがすべてカウントした後、少しだけ入力開始に猶予を持たせる
					return
				end

				if(InputDon() == true or this.currentTime_ >= this.kWaitEndTime_)then
					-- 待機終了
					this.state_:SetState("End")
				end

			end

			this.state_.func_["End"] = function()
				this.isEnd_ = true
			end
		end,

		-- 更新
		Update = function(this)
			-- ステート処理
			this.state_:Update()
		end,

		-- 段位の階級表示ボードの設定
		SetUpDaniBoard = function(this)
			Debug.PrintString("SetUpDaniBoardFinish")
			if(g_odaiDani_ == kDanShokyuu_)then this.mainMc_.com_dani_mc:GotoAndStop("syokyuu")
			elseif(g_odaiDani_ == kDan5kyuu_)then this.mainMc_.com_dani_mc:GotoAndStop("5kyuu")
			elseif(g_odaiDani_ == kDan4kyuu_)then this.mainMc_.com_dani_mc:GotoAndStop("4kyuu")
			elseif(g_odaiDani_ == kDan3kyuu_)then this.mainMc_.com_dani_mc:GotoAndStop("3kyuu")
			elseif(g_odaiDani_ == kDan2kyuu_)then this.mainMc_.com_dani_mc:GotoAndStop("2kyuu")
			elseif(g_odaiDani_ == kDan1kyuu_)then this.mainMc_.com_dani_mc:GotoAndStop("1kyuu")
			elseif(g_odaiDani_ == kDan1dan_)then this.mainMc_.com_dani_mc:GotoAndStop("1dan")
			elseif(g_odaiDani_ == kDan2dan_)then this.mainMc_.com_dani_mc:GotoAndStop("2dan")
			elseif(g_odaiDani_ == kDan3dan_)then this.mainMc_.com_dani_mc:GotoAndStop("3dan")
			elseif(g_odaiDani_ == kDan4dan_)then this.mainMc_.com_dani_mc:GotoAndStop("4dan")
			elseif(g_odaiDani_ == kDan5dan_)then this.mainMc_.com_dani_mc:GotoAndStop("5dan")
			elseif(g_odaiDani_ == kDan6dan_)then this.mainMc_.com_dani_mc:GotoAndStop("6dan")
			elseif(g_odaiDani_ == kDan7dan_)then this.mainMc_.com_dani_mc:GotoAndStop("7dan")
			elseif(g_odaiDani_ == kDan8dan_)then this.mainMc_.com_dani_mc:GotoAndStop("8dan")
			elseif(g_odaiDani_ == kDan9dan_)then this.mainMc_.com_dani_mc:GotoAndStop("9dan")
			elseif(g_odaiDani_ == kDan10dan_)then this.mainMc_.com_dani_mc:GotoAndStop("10dan")
			elseif(g_odaiDani_ == kDan11dan_)then this.mainMc_.com_dani_mc:GotoAndStop("11dan")
			elseif(g_odaiDani_ == kDan12dan_)then this.mainMc_.com_dani_mc:GotoAndStop("12dan")
			elseif(g_odaiDani_ == kDan13dan_)then this.mainMc_.com_dani_mc:GotoAndStop("13dan")
			elseif(g_odaiDani_ == kDan14dan_)then this.mainMc_.com_dani_mc:GotoAndStop("14dan")
			end
		end,

		-- 各曲ボードの設定
		SetUpBoard = function(this)
			Debug.PrintString("SetUpBoard")
			for idx = 1, 3 do
				this.board_[idx] = DaniResultSongBase.New(this.mainMc_:GetChildMc("song_board_0"..idx.."_mc",true))
				-- SetUp : songName, songNum, diff, diffNum, ryo, ka, fuka, renda, unreach
				this.board_[idx]:SetUp(g_songTitle_[idx], idx-1, g_difficulty_[idx], g_diffRank_[idx], g_goodNum_[idx], g_okNum_[idx], g_badNum_[idx], g_dramrollNum_[idx], g_unreach_[idx], g_isHidden_[idx])
				this.board_[idx]:InitSongData()
				this.board_[idx]:InitScoreData()

				-- カウントアップ無しの場合
				if(this.board_[idx].isUnreachSong_ == true)then
					this.board_[idx]:UnreachSkip()
				end
				this.board_[idx]:CountSkip()
			end
		end,

		-- 下地のスライドインSE再生
		SlideInSE = function(this)
			-- 大下地
			if(this.isSlideInEnd_[0] == false and this.mainMc_:IsInCurrentLabelMc("" ,"end_song") == true)then
				this.isSlideInEnd_[0] = true
				TSound:Play("se_daniresult_v12e","partial_plate")		-- SE
			end

			-- １枚目
			if(this.isSlideInEnd_[1] == false and this.mainMc_:IsInCurrentLabelMc("" ,"song_01") == true)then
				this.isSlideInEnd_[1] = true
				TSound:Play("se_daniresult_v12e","partial_plate")		-- SE
			end

			-- ２枚目
			if(this.isSlideInEnd_[2] == false and this.mainMc_:IsInCurrentLabelMc("" ,"song_02") == true)then
				this.isSlideInEnd_[2] = true
				TSound:Play("se_daniresult_v12e","partial_plate")		-- SE
			end

			-- ３枚目
			if(this.isSlideInEnd_[3] == false and this.mainMc_:IsInCurrentLabelMc("" ,"song_03") == true)then
				this.isSlideInEnd_[3] = true
				TSound:Play("se_daniresult_v12e","partial_plate")		-- SE
			end
		end,
	}
end