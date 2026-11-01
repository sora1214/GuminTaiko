-- tutorial.lua
-- 遊び方説明画面

-- 対応するlumenファイル
UseLumenFile = "lumen/000_default/tutorial/tutorial"

-- 使うクラスを読み込む
require("common.Sound")
require("common.State")

-- 初期化処理
function Init()
	-- シーケンス
	Tutorial = State.New("Tutorial")

	-- ステートマシン構築
	Tutorial.func_["Begin"] = function()
		Debug.PrintString("TutorialのBegin")

		-- ムービークリップ
		Debug.PrintString("ムービークリップの読み込み")

		-- ルートがメインのmc (ルートは""で取得可能)
		Tutorial.main_mc_ = Lumen.GetMovieClip("",true)

		Debug.PrintString("ムービークリップの読み込み完了")

		-- 左上どんちゃん
		Tutorial.don1p_ = Tutorial.main_mc_:GetChildMc("don1p",true)
		Don.CameraReverse(0,false)
		Don.SetLoopAnimation(0,"normal",false)

		-- テキストの設定

		-- 説明スキップ文言
		Tutorial.main_skip_message_mc_ = Tutorial.main_mc_:GetChildMc("skip_message_instance",true)
		Tutorial.main_skip_message_tx_mc_ = Tutorial.main_skip_message_mc_:GetChildMc("skip_message_tx_instance",true)
		Tutorial.main_skip_message_tx_mc_:SetText("tx_skip_instance","tutorial_99_001")

		-- 説明スキップカウント
		Tutorial.katsu_counter_ = 0		-- "カツ"を叩いた数
		Tutorial.skip_wait_flag_ = false	-- 待機中は"カツ"を叩いてもカウントしない
		Tutorial.skip_flag_ = false
		Tutorial.skip_end_flag_ = false
		Tutorial.main_skip_counter_mc_ = Tutorial.main_mc_:GetChildMc("skipCounter_instance",true)

		Tutorial.skip_wait_flag_ = true

		-- フェードアウト
		Tutorial.is_fadeout_flag_ = false

		-- ゲージ上の"クリア"
		Tutorial.fade_lane_instance = Tutorial.main_mc_:GetChildMc("fade_lane_instance",true)
		Tutorial.clear_tx_instance = Tutorial.fade_lane_instance:GetChildMc("clear_text_instance",true)
		Tutorial.clear_tx_instance:SetText("text","tutorial_99_002")

		-- "Loading"ラベルに跳ぶ
		Tutorial.main_mc_:GotoAndPlay("Loading")
		Tutorial:SetState("Loading")

		-- スコア関連
		Lumen.LoadMovie("lumen/000_default/enso_normal/enso/information/score","dummy_score_instance_1")
		Lumen.LoadMovie("lumen/000_default/enso_normal/enso/information/score","dummy_score_instance_2")
		Lumen.LoadMovie("lumen/000_default/enso_normal/enso/information/score","dummy_score_instance_3")
		Lumen.LoadMovie("lumen/000_default/enso_normal/enso/information/score","dummy_score_instance_4")

		Tutorial.current_score = 0
		Tutorial.addScoreMax = 4
		Tutorial.addScore_current_id = 0
		Tutorial.addScoreList = {}

		-- くす玉関連
		Lumen.LoadMovie("lumen/000_default/enso_normal/enso/onpu/action_kusudama","dummy_kusudama_instance")

		-- BGM & SE
		TSound:LoadBank("bgm_howtoplay_v12a")

		TSound:LoadBank("se_howtoplay_v12a")	-- 遊び方説明
		TSound:LoadBank("se_enso_v12a")			-- 演奏モード
		TSound:LoadBank("se_neiro_00_v12a")		-- 演奏ゲーム叩いた音
		TSound:LoadBank("voice_howtoplay_v12a")	-- ボイス再生

		-- フレームレート計算用
		Tutorial.fps_num = Common.FPS / 60
	end

	-- 読み込み中と完了後の処理
	Tutorial.func_["Loading"] = function()
		if(Lumen.IsLoadMovieFinish() == true and Don.IsLoadedDonAll() and TSound:LoadedBankAll()) then
			Debug.PrintString("読み込み完了")
			-- メインスコア
			Tutorial.score_main_mc_ = Lumen.GetMovieClip("dummy_score_instance_1",true)
			Tutorial.score_mc_ = Tutorial.score_main_mc_:GetChildMc("score",true)
			Tutorial.score_mc_:GetChildMc("kirakira",true):SetVisible(false)
			Tutorial.score_mc_:GetChildMc("high_score_bg",true):SetVisible(false)
			Tutorial.score_main_mc_:GetChildMc("high_score_anim",true):SetVisible(false)

			Tutorial.score_digit_mc_ = {}
			for i = 0,7 - 1 do
				Tutorial.score_digit_mc_[i] = Tutorial.score_mc_:GetChildMc("digit"..i + 1, true)
				Debug.PrintString("light")
				Tutorial.score_digit_mc_[i]:GetChildMc("light", true):SetVisible(false)
			end
			TutorialScore.ScoreUpdate()
			
			-- main以外のスコア
			Tutorial.score_2_mc_ = Lumen.GetMovieClip("dummy_score_instance_2",true)
			Tutorial.score_3_mc_ = Lumen.GetMovieClip("dummy_score_instance_3",true)
			Tutorial.score_4_mc_ = Lumen.GetMovieClip("dummy_score_instance_4",true)

			Tutorial.score_2_score_mc_ = Tutorial.score_2_mc_:GetChildMc("score",true)
			Tutorial.score_3_score_mc_ = Tutorial.score_3_mc_:GetChildMc("score",true)
			Tutorial.score_4_score_mc_ = Tutorial.score_4_mc_:GetChildMc("score",true)

			Tutorial.score_2_score_mc_:GetChildMc("high_score_bg",true):SetVisible(false)
			Tutorial.score_3_score_mc_:GetChildMc("high_score_bg",true):SetVisible(false)
			Tutorial.score_4_score_mc_:GetChildMc("high_score_bg",true):SetVisible(false)

			Tutorial.score_2_score_mc_:GetChildMc("kirakira",true):SetVisible(false)
			Tutorial.score_3_score_mc_:GetChildMc("kirakira",true):SetVisible(false)
			Tutorial.score_4_score_mc_:GetChildMc("kirakira",true):SetVisible(false)

			Tutorial.score_2_mc_:GetChildMc("score",true):SetVisible(false)
			Tutorial.score_3_mc_:GetChildMc("score",true):SetVisible(false)
			Tutorial.score_4_mc_:GetChildMc("score",true):SetVisible(false)

			Tutorial.score_2_mc_:GetChildMc("base",true):SetVisible(false)
			Tutorial.score_3_mc_:GetChildMc("base",true):SetVisible(false)
			Tutorial.score_4_mc_:GetChildMc("base",true):SetVisible(false)

			Tutorial.score_2_mc_:GetChildMc("high_score_anim",true):SetVisible(false)
			Tutorial.score_3_mc_:GetChildMc("high_score_anim",true):SetVisible(false)
			Tutorial.score_4_mc_:GetChildMc("high_score_anim",true):SetVisible(false)

			-- 加算スコア
			Tutorial.add_score_main_mc_ = {}
			Tutorial.add_score_main_mc_[0] = Lumen.GetMovieClip("dummy_score_instance_1",true)
			Tutorial.add_score_main_mc_[1] = Lumen.GetMovieClip("dummy_score_instance_2",true)
			Tutorial.add_score_main_mc_[2] = Lumen.GetMovieClip("dummy_score_instance_3",true)
			Tutorial.add_score_main_mc_[3] = Lumen.GetMovieClip("dummy_score_instance_4",true)
			add_score_CreateLoop()

			-- BGM & SE
			TSound:PlayBGM("bgm_howtoplay_v12a")

			TSound:Play("voice_howtoplay_v12a","howtoplay_01")

--			TSound:LoadBank("se_howtoplay_v12a")	-- 遊び方説明
--			TSound:LoadBank("se_enso_v12a")			-- 演奏モード
--			TSound:LoadBank("se_neiro_00_v12a")		-- 演奏ゲーム叩いた音
--			TSound:LoadBank("voice_howtoplay_v12a")	-- ボイス再生
			

			-- "fade_in"ラベルに跳ぶ
			Tutorial.main_mc_:GotoAndPlay("fade_in")
			Tutorial:SetState("fade_in")
		end
	end

	Tutorial.func_["fade_in"] = function()
		-- stopがかかったら次のシーンに移る
		if(Tutorial.main_mc_:IsPlay() == false) then
			Tutorial:SetState("BGM_start_wait")

			-- ルートをラベル"scene_01"に移す
			Tutorial.main_mc_:GotoAndPlay("scene_01")
			Tutorial.scene_mc_ = Lumen.GetMovieClip("scene_01_instance",true)
			Tutorial.scene_mc_:GotoAndStop(1)

			-- テキストウィンドウのムービークリップ取得
			Tutorial.scene_child_mc_ = Tutorial.scene_mc_:GetChildMc("scene_window_tx_instance",true)
			Tutorial.scene_child_mc_:SetText("tx_window_instance","tutorial_01_001")

			--ゲージ上の"クリア"テキスト
			Tutorial.scene_01_clear_tx_instance = Tutorial.scene_mc_:GetChildMc("clear_text_instance",true)
			Tutorial.scene_01_clear_tx_instance:SetText("text","tutorial_99_002")

			-- ボイス再生
			--TSound:Play("voice_howtoplay_v12a","howtoplay_01")

			Tutorial.skip_wait_flag_ = false
		end
	end

	Tutorial.func_["BGM_start_wait"] = function()
		-- BGMが開始してから2秒待機
		if(Tutorial.count_ >= 2 * 60 * Tutorial.fps_num) then
			-- 変数を次のものにする
--			Tutorial.scene_mc_ = Lumen.GetMovieClip("scene_01_instance",true)

			-- テキストウィンドウのムービークリップ取得
--			Tutorial.scene_child_mc_ = Tutorial.scene_mc_:GetChildMc("scene_window_tx_instance",true)
--			Tutorial.scene_child_mc_:SetText("tx_window_instance","tutorial_01_001")

			--ゲージ上の"クリア"テキスト
--			Tutorial.scene_01_clear_tx_instance = Tutorial.scene_mc_:GetChildMc("clear_text_instance",true)
--			Tutorial.scene_01_clear_tx_instance:SetText("text","tutorial_99_002")

			-- ボイス再生
			TSound:Play("voice_howtoplay_v12a","howtoplay_02")

			-- ルートをラベル"scene_01"に移す
			--Tutorial.main_mc_:GotoAndPlay("scene_01")

			-- "fade_in"ラベルに跳ぶ
			Tutorial:SetState("scene_01")
			Tutorial.scene_mc_:GotoAndPlay(1)
		end
	end

	Tutorial.func_["scene_01"] = function()
		-- stopがかかったら次のシーンに移る
		if(Tutorial.scene_mc_:IsPlay() == false) then
			-- ルートをラベル"scene_02"に移す
			Tutorial.main_mc_:GotoAndPlay("scene_02")
			-- 変数を次のものにする
			Tutorial.scene_mc_ = Lumen.GetMovieClip("scene_02_instance",true)

			-- テキストウィンドウのムービークリップ取得
			Tutorial.scene_child_mc_ = Tutorial.scene_mc_:GetChildMc("scene_window_tx_instance",true)
			Tutorial.scene_child_mc_:SetText("tx_window_instance","tutorial_02_001")

			--ゲージ上の"クリア"テキスト
			Tutorial.scene_02_clear_tx_instance = Tutorial.scene_mc_:GetChildMc("clear_text_instance",true)
			Tutorial.scene_02_clear_tx_instance:SetText("text","tutorial_99_002")

			-- ボイス再生
			TSound:Play("voice_howtoplay_v12a","howtoplay_03")

			-- シーンを最初から再生する
			Tutorial.scene_mc_:GotoAndPlay(1)
			Tutorial:SetState("scene_02")
		end
	end

	Tutorial.func_["scene_02"] = function()
		-- スコア加算
		tutorial_score_plus_scene2(Tutorial.count_)
		--tutorial_score_plus_scene2(Tutorial.scene_mc_.current_frame)

		-- stopがかかったら次のシーンに移る
		if(Tutorial.scene_mc_:IsPlay() == false) then
		-- ルートをラベル"scene_03"に移す
			Tutorial.main_mc_:GotoAndPlay("scene_03")
			-- 変数を次のものにする
			Tutorial.scene_mc_ = Lumen.GetMovieClip("scene_03_instance",true)

			-- テキストウィンドウのムービークリップ取得
			Tutorial.scene_child_mc_ = Tutorial.scene_mc_:GetChildMc("scene_window_tx_instance",true)
			Tutorial.scene_child_mc_:SetText("tx_window_instance","tutorial_03_001")

			--ゲージ上の"クリア"テキスト
			Tutorial.scene_03_clear_tx_instance = Tutorial.scene_mc_:GetChildMc("clear_text_instance",true)
			Tutorial.scene_03_clear_tx_instance:SetText("text","tutorial_99_002")

			-- ボイス再生
			TSound:Play("voice_howtoplay_v12a","howtoplay_04")

			-- シーンを最初から再生する
			Tutorial.scene_mc_:GotoAndPlay(1)
			Tutorial:SetState("scene_03")
		end
	end

	Tutorial.func_["scene_03"] = function()
		-- 音声の再生
		tutorial_se_scene3(Tutorial.count_)

		-- stopがかかったら次のシーンに移る
		if(Tutorial.scene_mc_:IsPlay() == false) then
		-- ルートをラベル"scene_04"に移す
			Tutorial.main_mc_:GotoAndPlay("scene_04")
			-- 変数を次のものにする
			Tutorial.scene_mc_ = Lumen.GetMovieClip("scene_04_instance",true)

			-- テキストウィンドウのムービークリップ取得
			Tutorial.scene_child_mc_ = Tutorial.scene_mc_:GetChildMc("scene_window_tx_instance",true)
			Tutorial.scene_child_mc_:SetText("tx_window_instance","tutorial_04_001")

			--ゲージ上の"クリア"テキスト
			Tutorial.scene_04_clear_tx_instance = Tutorial.scene_mc_:GetChildMc("clear_text_instance",true)
			Tutorial.scene_04_clear_tx_instance:SetText("text","tutorial_99_002")

			-- ボイス再生
			TSound:Play("voice_howtoplay_v12a","howtoplay_05")

			-- シーンを最初から再生する
			Tutorial.scene_mc_:GotoAndPlay(1)
			Tutorial:SetState("scene_04")
		end
	end

	Tutorial.func_["scene_04"] = function()
		-- スコア加算
		tutorial_score_plus_scene4(Tutorial.count_)

		-- stopがかかったら次のシーンに移る
		if(Tutorial.scene_mc_:IsPlay() == false) then
		-- ルートをラベル"scene_05"に移す
			Tutorial.main_mc_:GotoAndPlay("scene_05")
			-- 変数を次のものにする
			Tutorial.scene_mc_ = Lumen.GetMovieClip("scene_05_instance",true)

			-- テキストウィンドウのムービークリップ取得
			Tutorial.scene_child_mc_ = Tutorial.scene_mc_:GetChildMc("scene_window_tx_instance",true)
			Tutorial.scene_child_mc_:SetText("tx_window_instance","tutorial_05_001")

			--ゲージ上の"クリア"テキスト
			Tutorial.scene_05_clear_tx_instance = Tutorial.scene_mc_:GetChildMc("clear_text_instance",true)
			Tutorial.scene_05_clear_tx_instance:SetText("text","tutorial_99_002")

			-- ボイス再生
			TSound:Play("voice_howtoplay_v12a","howtoplay_06")

			-- シーンを最初から再生する
			Tutorial.scene_mc_:GotoAndPlay(1)
			Tutorial:SetState("scene_05")
		end
	end

	Tutorial.func_["scene_05"] = function()
		-- スコア加算
		tutorial_score_plus_scene5(Tutorial.count_)

		-- stopがかかったら次のシーンに移る
		if(Tutorial.scene_mc_:IsPlay() == false) then
		-- ルートをラベル"scene_06"に移す
			Tutorial.main_mc_:GotoAndPlay("scene_06")
			-- 変数を次のものにする
			Tutorial.scene_mc_ = Lumen.GetMovieClip("scene_06_instance",true)

			-- テキストウィンドウのムービークリップ取得
			Tutorial.scene_child_mc_ = Tutorial.scene_mc_:GetChildMc("scene_window_tx_instance",true)
			Tutorial.scene_child_mc_:SetText("tx_window_instance","tutorial_06_001")

			--ゲージ上の"クリア"テキスト
			Tutorial.scene_06_clear_tx_instance = Tutorial.scene_mc_:GetChildMc("clear_text_instance",true)
			Tutorial.scene_06_clear_tx_instance:SetText("text","tutorial_99_002")

			-- ボイス再生
			TSound:Play("voice_howtoplay_v12a","howtoplay_07")

			-- シーンを最初から再生する
			Tutorial.scene_mc_:GotoAndPlay(1)
			Tutorial:SetState("scene_06")
		end
	end

	Tutorial.func_["scene_06"] = function()
		-- スコア加算
		tutorial_score_plus_scene6(Tutorial.count_)

		-- stopがかかったら次のシーンに移る
		if(Tutorial.scene_mc_:IsPlay() == false) then
		-- ルートをラベル"scene_07"に移す
			Tutorial.main_mc_:GotoAndPlay("scene_07")
			-- 変数を次のものにする
			Tutorial.scene_mc_ = Lumen.GetMovieClip("scene_07_instance",true)

			-- テキストウィンドウのムービークリップ取得
			Tutorial.scene_child_mc_ = Tutorial.scene_mc_:GetChildMc("scene_window_tx_instance",true)
			Tutorial.scene_child_mc_:SetText("tx_window_instance","tutorial_07_001")

			--ゲージ上の"クリア"テキスト
			Tutorial.scene_07_clear_tx_instance = Tutorial.scene_mc_:GetChildMc("clear_text_instance",true)
			Tutorial.scene_07_clear_tx_instance:SetText("text","tutorial_99_002")

			-- ボイス再生
			TSound:Play("voice_howtoplay_v12a","howtoplay_08")

			-- シーンを最初から再生する
			Tutorial.scene_mc_:GotoAndPlay(1)
			Tutorial:SetState("scene_07")
		end
	end

	Tutorial.func_["scene_07"] = function()
		-- スコア加算
		tutorial_score_plus_scene7(Tutorial.count_)

		-- stopがかかったら次のシーンに移る
		if(Tutorial.scene_mc_:IsPlay() == false) then
		-- ルートをラベル"scene_08"に移す
			Tutorial.main_mc_:GotoAndPlay("scene_08")
			-- 変数を次のものにする
			Tutorial.scene_mc_ = Lumen.GetMovieClip("scene_08_instance",true)

			-- くす玉関連
			Tutorial.kusudama_mc_ = Tutorial.scene_mc_:GetChildMc("dummy_kusudama_instance",true)
			Tutorial.kusudama_root_mc_ = Tutorial.kusudama_mc_:GetChildMc("main",true)
			Debug.PrintString("init")
			tutorial_kusudama_init()

			-- テキストウィンドウのムービークリップ取得
			Tutorial.scene_child_mc_ = Tutorial.scene_mc_:GetChildMc("scene_window_tx_instance",true)
			Tutorial.scene_child_mc_:SetText("tx_window_instance","tutorial_08_001")

			--ゲージ上の"クリア"テキスト
			Tutorial.scene_08_clear_tx_instance = Tutorial.scene_mc_:GetChildMc("clear_text_instance",true)
			Tutorial.scene_08_clear_tx_instance:SetText("text","tutorial_99_002")

			-- ボイス再生
			TSound:Play("voice_howtoplay_v12a","howtoplay_09")

			-- シーンを最初から再生する
			Tutorial.scene_mc_:GotoAndPlay(1)
			Tutorial:SetState("scene_08")
		end
	end

	Tutorial.func_["scene_08"] = function()
		-- スコア加算
		tutorial_score_plus_scene8(Tutorial.count_)

		-- くす玉
		tutorial_kusudama_Update(Tutorial.count_)

		-- stopがかかったら次のシーンに移る
		if(Tutorial.scene_mc_:IsPlay() == false) then
		-- ルートをラベル"scene_09"に移す
			Tutorial.main_mc_:GotoAndPlay("scene_09")
			-- 変数を次のものにする
			Tutorial.scene_mc_ = Lumen.GetMovieClip("scene_09_instance",true)

			-- テキストウィンドウのムービークリップ取得
			Tutorial.scene_child_mc_ = Tutorial.scene_mc_:GetChildMc("scene_window_tx_instance",true)
			Tutorial.scene_child_mc_:SetText("tx_window_instance","tutorial_09_001")

			--ゲージ上の"クリア"テキスト
			Tutorial.scene_09_clear_tx_instance = Tutorial.scene_mc_:GetChildMc("clear_text_instance",true)
			Tutorial.scene_09_clear_tx_instance:SetText("text","tutorial_99_002")

			-- ボイス再生
			TSound:Play("voice_howtoplay_v12a","howtoplay_10")

			-- シーンを最初から再生する
			Tutorial.scene_mc_:GotoAndPlay(1)
			Tutorial:SetState("scene_09")
		end
	end

	Tutorial.func_["scene_09"] = function()
		-- スコア加算
		tutorial_score_plus_scene9(Tutorial.count_)

		-- stopがかかったら次のシーンに移る
		if(Tutorial.scene_mc_:IsPlay() == false) then
		-- ルートをラベル"scene_10"に移す
			Tutorial.main_mc_:GotoAndPlay("scene_10")
			-- 変数を次のものにする
			Tutorial.scene_mc_ = Lumen.GetMovieClip("scene_10_instance",true)

			-- テキストウィンドウのムービークリップ取得
			Tutorial.scene_child_mc_ = Tutorial.scene_mc_:GetChildMc("scene_window_tx_instance",true)
			Tutorial.scene_child_mc_:SetText("tx_window_instance","tutorial_10_001")

			--ゲージ上の"クリア"テキスト
			Tutorial.scene_10_clear_tx_01_instance = Tutorial.scene_mc_:GetChildMc("clear_text_instance",true)
			Tutorial.scene_10_clear_tx_01_instance:SetText("text","tutorial_99_002")

			-- "ここを超えればクリア"テキスト
			Tutorial.scene_10_clear_tx_02_instance = Tutorial.scene_mc_:GetChildMc("scene_clear_tx_instance",true)
			Tutorial.scene_10_clear_tx_02_instance:SetText("tx_clear","tutorial_99_003")

			-- ボイス再生
			TSound:Play("voice_howtoplay_v12a","howtoplay_11")

			-- シーンを最初から再生する
			Tutorial.scene_mc_:GotoAndPlay(1)
			Tutorial:SetState("scene_10")
		end
	end

	Tutorial.func_["scene_10"] = function()
		-- se再生
		tutorial_se_scene10(Tutorial.count_)

		-- stopがかかったら次のシーンに移る
		if(Tutorial.scene_mc_:IsPlay() == false) then
			-- フェード時の魂ゲージ制御の為
			--Tutorial.fade_lane_instance = Tutorial.main_mc_:GetChildMc("fade_lane_instance",true)

			Tutorial.fade_lane_instance:GotoAndPlay("fade_out")
			Tutorial.main_mc_:GotoAndStop("fade_out")
			Tutorial:SetState("BGM_end_wait")
		end
	end

	Tutorial.func_["BGM_end_wait"] = function()
		-- BGMが終わるまで待機
--		if(isBGM == false) then
		
		if(TSound:IsPlayingBGM() == false) then
			-- "fade_in"ラベルに跳ぶ
			Tutorial.is_fadeout_flag_ = true
			Tutorial.main_mc_:GotoAndPlay("fade_out")
			Tutorial:SetState("fade_out")
		end
	end

	Tutorial.func_["fade_out"] = function()
		-- stopがかかったら次のシーンに移る
		if(Tutorial.main_mc_:IsPlay() == false) then
			Tutorial:SetState("EndWait")
		end
	end

	Tutorial.func_["EndWait"] = function()
		-- シーン終了
		Common.LuaFinish()
		Tutorial:SetState("End")
	end
	Tutorial.func_["EntryEndWait"] = function()
		-- シーン終了
		Common.LuaFinish(1)
		Tutorial:SetState("End")
	end
	Tutorial.func_["End"] = function()
	end
end

-- 毎フレームの処理
function Proc()
	Tutorial:Update()

	if(Tutorial.is_fadeout_flag_ == false)then
		-- スキップ入力
		Katsu()

		-- スキップ
		if(Tutorial.skip_end_flag_ == false and Tutorial.skip_flag_ == true) then
			skip()
		end
	end

	-- スコア
	TutorialScore.Score_ListUpdate()

	--test
--	if(Input.GetTrigger(Input.ALLPLAYER_UP)) then
--		Don.SetNonLoopAnimation(0,"kusu_success01_p1",false)		-- くす玉モーションに入る瞬間
--	end
--
--	if(Input.GetTrigger(Input.ALLPLAYER_DOWN)) then
--		test_play_scene()
--	end
	
end

----------------------------------------
-- シーン選択
----------------------------------------
function test_play_scene()
	-- シーンを最初から再生する
	Tutorial.main_mc_:GotoAndPlay("scene_07")
	Tutorial.scene_mc_ = Lumen.GetMovieClip("scene_7_instance",true)
	Tutorial.scene_mc_:GotoAndPlay(1)
	Tutorial:SetState("scene_07")
end

----------------------------------------
-- スキップ
----------------------------------------

-- スキップ入力があった場合の処理
function Katsu()
	if Tutorial.skip_wait_flag_ then
		return
	end

	Tutorial.flag = false

	if(isLeftPlayer == true and isRightPlayer == false) then
		-- 左プレイヤー
		if(Input.GetTrigger(Input.PLAYER1_LEFT) or Input.GetTrigger(Input.PLAYER1_RIGHT)) then
			Tutorial.flag = true
		end
	elseif(isLeftPlayer == false and isRightPlayer == true) then
		-- 右プレイヤー
		if(Input.GetTrigger(Input.PLAYER2_LEFT) or Input.GetTrigger(Input.PLAYER2_RIGHT)) then
			Tutorial.flag = true
		end
	elseif(isLeftPlayer == true and isRightPlayer == true) then
		-- 二人プレイ
		if(Input.GetTrigger(Input.ALLPLAYER_LEFT) or Input.GetTrigger(Input.ALLPLAYER_RIGHT)) then
			Tutorial.flag = true
		end
	end

	-- 入力があった場合
	if(Tutorial.flag) then
		-- スキップアイコンの演出中ではない
		if(Tutorial.main_skip_counter_mc_:IsPlay() == false and Tutorial.skip_flag_ == false) then
			Tutorial.katsu_counter_ = Tutorial.katsu_counter_ + 1
			Tutorial.main_skip_counter_mc_:GotoAndPlay(string.format("add_%d",Tutorial.katsu_counter_))

			TSound:Play("se_common_v12a","katsu_c")

			if Tutorial.katsu_counter_ >= 5 then
				Tutorial.skip_flag_ = true
			end
		end
	end
end

-- スキップ入力が5回押された後の処理
function skip()
	-- 演出が終了次第、EndWaitへ
	if(Tutorial.main_skip_counter_mc_:IsPlay() == false) then
		Tutorial.main_mc_:GotoAndPlay("fade_out")
		Tutorial:SetState("fade_out")

		Tutorial.skip_end_flag_ = true
	end
end

----------------------------------------
-- スコア
----------------------------------------
-- スコア本体の加算動作
TutorialScore = {}
TutorialScore.new = function(num)
	local obj = {}
	obj.counter = 0
	obj.plus = num
	return obj
end

-- 生成
TutorialScore.Create = function(num)
	table.insert(Tutorial.addScoreList, TutorialScore.new(num))
end

-- 更新
TutorialScore.Score_ListUpdate = function()
	for i, s in ipairs(Tutorial.addScoreList) do
		s.counter = s.counter + 1
		if s.counter > 32 * Tutorial.fps_num then
			-- スコアの値を加算して跳ねる
			Tutorial.current_score = Tutorial.current_score + s.plus
			Debug.PrintString("score update")
			TutorialScore.ScoreUpdate()
			table.remove(Tutorial.addScoreList, i)
		end
	end
end

-- スコアの数値の更新
TutorialScore.ScoreUpdate = function()
	-- numをdigit0~5に入れていく
	Debug.PrintString("score ="..Tutorial.current_score)
	local s = string.format( "%d", Tutorial.current_score )
	local str = ""
	for i = 0,#s do
		str = str..s:sub(#s-i,#s-i)
	end

	for j = 0,7-1 do
		if j < #str then
			-- 文字数内
			Tutorial.score_digit_mc_[j]:GotoAndPlay("number_"..str:sub(j+1, j+1))
		else
			-- 文字数以上
			Tutorial.score_digit_mc_[j]:GotoAndPlay("none")
		end
	end
end

-- 音声を再生する場合
function score_plus_sound(num, bank, tone)
	Debug.PrintString("DonKatsu Sound, bank = "..bank..", tone = "..tone)
	TSound:Play(bank,tone)
	score_plus(num)
end

-- スコアの加算(5桁まで)
function score_plus(num)
	-- スコア計算
	TutorialScore.Create(num)

	-- numをdigit0~5に入れていく
	local s = string.format( "%d", num )
	local str = ""
	for i = 0,#s do
		str = str..s:sub(#s-i,#s-i)
	end

	for j = 0,6 - 1 do
		if j < #str then
			-- 文字数内
			Tutorial.addScore_mc_[Tutorial.addScore_current_id].digit[j]:GotoAndPlay("number_"..str:sub(j+1, j+1))
		else
			-- 文字数以上
			Tutorial.addScore_mc_[Tutorial.addScore_current_id].digit[j]:GotoAndPlay("none")
		end
	end
	-- 描画
	Tutorial.addScore_mc_[Tutorial.addScore_current_id].mc:GotoAndPlay(1)

	-- エフェクト番号を進める
	Tutorial.addScore_current_id = Tutorial.addScore_current_id + 1
	if Tutorial.addScore_current_id >= Tutorial.addScoreMax then
		Tutorial.addScore_current_id = 0
	end
end

-- 加算用スコアを複数作成
function add_score_CreateLoop()
	-- 必要分生成
	Tutorial.addScore_mc_ = {}
	for i = 0,Tutorial.addScoreMax - 1 do
		Tutorial.addScore_mc_[i] = TutorialAddScore.new(i)
	end
end

-- 加算スコアクラス
TutorialAddScore = {}
TutorialAddScore.new = function(num)
	local obj = {}
	
	Tutorial.add_score_main_mc_[num]:GetChildMc("add_score_l_mc", true):GotoAndStop(1)
	Tutorial.add_score_main_mc_[num]:GetChildMc("add_score_r_1p_mc", true):GotoAndStop(1)
	obj.mc = Tutorial.add_score_main_mc_[num]:GetChildMc("add_score_l_mc", true)
	obj.mc:GotoAndStop(1)

	obj.digit = {}
	for i = 0,6 - 1 do
		obj.digit[i] = obj.mc:GetChildMc("digit"..i + 1, true)
		Debug.PrintString("add light")
	end
	obj.digit[0]:GotoAndStop("number_"..num)
	return obj
end

-- スコア加算タイミング(チュートリアル用)
function tutorial_score_plus_scene2(frame)
	if frame == 300 * Tutorial.fps_num then TSound:Play("se_common_v12a","don_c")		end
	if frame == 361 * Tutorial.fps_num then score_plus(5000)	end
end

-- se再生タイミング
function tutorial_se_scene3(frame)
	if frame == 125 * Tutorial.fps_num then TSound:Play("se_howtoplay_v12a","hit_side") end
	if frame == 149 * Tutorial.fps_num then TSound:Play("se_howtoplay_v12a","hit_side") end
	if frame == 174 * Tutorial.fps_num then TSound:Play("se_howtoplay_v12a","hit_side") end
	if frame == 191 * Tutorial.fps_num then TSound:Play("se_common_v12a","caution_buzzer") end
end

function tutorial_score_plus_scene4(frame)
	if frame == 300 * Tutorial.fps_num then score_plus_sound(5000,"se_common_v12a","don_c") end
end

function tutorial_score_plus_scene5(frame)
	if frame == 300 * Tutorial.fps_num then score_plus_sound(5000,"se_common_v12a","katsu_c") end
end

function tutorial_score_plus_scene6(frame)
	if frame == 300 * Tutorial.fps_num then score_plus_sound(5000,"se_common_v12a","don_c") end
end

function tutorial_score_plus_scene7(frame)
	if frame == 300 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 305 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 310 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 315 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 320 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 325 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 330 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 335 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 340 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 345 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 350 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 355 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 360 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 365 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 370 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
end

function tutorial_score_plus_scene8(frame)
--	--風船
	if frame == 301 * Tutorial.fps_num then Tutorial.don1p_:SetVisible(false) end
	if frame == 395 * Tutorial.fps_num then Tutorial.don1p_:SetVisible(true) end

	if frame == 301 * Tutorial.fps_num then Don.SetLoopAnimation(0,"balloon_loop",false); end	--ふくらましループ
	if frame == 311 * Tutorial.fps_num then Don.SetNonLoopAnimation(0,"balloon_nobeat",false); end
	if frame == 321 * Tutorial.fps_num then Don.SetNonLoopAnimation(0,"balloon_nobeat",false); end
	if frame == 331 * Tutorial.fps_num then Don.SetNonLoopAnimation(0,"balloon_nobeat",false); end
	if frame == 341 * Tutorial.fps_num then Don.SetNonLoopAnimation(0,"balloon_nobeat",false); end
	if frame == 351 * Tutorial.fps_num then Don.SetNonLoopAnimation(0,"balloon_nobeat",false); end
	if frame == 361 * Tutorial.fps_num then Don.SetNonLoopAnimation(0,"balloon_success",true); end

	if frame == 390 * Tutorial.fps_num then Don.SetLoopAnimation(0,"normal",false); end

	if frame == 301 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end	--6
	if frame == 311 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 321 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 331 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 341 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 351 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	
	if frame == 361 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end	--break
	if frame == 361 * Tutorial.fps_num then TSound:Play("se_enso_v12a","balloon_success_c") end		--break se
	
	--くすだま
	if frame == 752 * Tutorial.fps_num then Tutorial.don1p_:SetVisible(false) end
	if frame == 910 * Tutorial.fps_num then Tutorial.don1p_:SetVisible(true) end

	if frame == 752 * Tutorial.fps_num then Don.SetNonLoopAnimation(0,"kusu_in_p1",false); end
	if frame == 771 * Tutorial.fps_num then Don.SetLoopAnimation(0,"kusu_nobeat_p1",false); end
	if frame == 781 * Tutorial.fps_num then Don.SetNonLoopAnimation(0,"kusu_loop_p1",false); end
	if frame == 791 * Tutorial.fps_num then Don.SetNonLoopAnimation(0,"kusu_loop_p1",false); end
	if frame == 801 * Tutorial.fps_num then Don.SetNonLoopAnimation(0,"kusu_loop_p1",false); end
	if frame == 811 * Tutorial.fps_num then Don.SetNonLoopAnimation(0,"kusu_loop_p1",false); end
	if frame == 821 * Tutorial.fps_num then Don.SetNonLoopAnimation(0,"kusu_loop_p1",false); end
	if frame == 831 * Tutorial.fps_num then Don.SetNonLoopAnimation(0,"kusu_loop_p1",false); end
	if frame == 841 * Tutorial.fps_num then Don.SetNonLoopAnimation(0,"kusu_loop_p1",false); end
	if frame == 851 * Tutorial.fps_num then Don.SetNonLoopAnimation(0,"kusu_loop_p1",false); end
	if frame == 861 * Tutorial.fps_num then Don.SetNonLoopAnimation(0,"kusu_success02_p1",true) end
	if frame == 910 * Tutorial.fps_num then Don.SetLoopAnimation(0,"normal",false) end

	if frame == 771 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end	--in
	if frame == 781 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 791 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 801 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 811 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 821 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 831 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 841 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 851 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end
	if frame == 861 * Tutorial.fps_num then score_plus_sound(100, "se_common_v12a", "don_c") end	--open
	
	if frame == 861 * Tutorial.fps_num then TSound:Play("se_enso_v12a","kusudama_success") end		--open se

	
end

function tutorial_score_plus_scene9(frame)
	if frame == 200 * Tutorial.fps_num then score_plus_sound(5000, "se_common_v12a", "don_c") end
	if frame == 220 * Tutorial.fps_num then score_plus_sound(5000, "se_common_v12a", "don_c") end
	if frame == 260 * Tutorial.fps_num then score_plus_sound(5000, "se_common_v12a", "don_c") end
	if frame == 280 * Tutorial.fps_num then score_plus_sound(5000, "se_common_v12a", "don_c") end
	if frame == 321 * Tutorial.fps_num then score_plus_sound(5000, "se_common_v12a", "katsu_c") end
	if frame == 400 * Tutorial.fps_num then score_plus_sound(5000, "se_common_v12a", "don_c") end	-- 大ドン
	if frame == 440 * Tutorial.fps_num then score_plus_sound(5000, "se_common_v12a", "don_c") end	-- 大ドン
end

function tutorial_se_scene10(frame)
	if frame == 154 * Tutorial.fps_num then TSound:Play("se_howtoplay_v12a","achieve_clear") end	-- クリアライン
	if frame == 360 * Tutorial.fps_num then TSound:Play("se_howtoplay_v12a","achieve_tamashii") end	-- 魂ゲージ
end

----------------------------------------
-- くす玉
----------------------------------------
function tutorial_kusudama_init()
	Tutorial.kusudama_isActive = false

	-- 開始までストップ
	Debug.PrintString("go")
	Tutorial.kusudama_root_mc_:GotoAndStop(1)

	--mc
	Debug.PrintString("mc")
	Tutorial.kusudama_hit_mc = Tutorial.kusudama_root_mc_:GetChildMc("kusudama_hit",true)
	Tutorial.kusudama_rendas_text_mc = Tutorial.kusudama_root_mc_:GetChildMc("rendas_text",true)
	Tutorial.kusudama_renda_counter_mc = Tutorial.kusudama_root_mc_:GetChildMc("renda_counter",true)

	Tutorial.kusudama_success_high_mc = Tutorial.kusudama_root_mc_:GetChildMc("kusudama_success_high",true)
	Tutorial.kusudama_success_low_mc = Tutorial.kusudama_root_mc_:GetChildMc("kusudama_success_low",true)
	Tutorial.kusudama_miss_mc = Tutorial.kusudama_root_mc_:GetChildMc("kusudama_miss",true)

	-- digit
	Debug.PrintString("digit")
	Tutorial.digit1_1_mc = Tutorial.kusudama_renda_counter_mc:GetChildMc("digit1_1",true)
	Tutorial.digit10_1_mc = Tutorial.kusudama_renda_counter_mc:GetChildMc("digit10_1",true)
	Tutorial.digit10_2_mc = Tutorial.kusudama_renda_counter_mc:GetChildMc("digit10_2",true)
	Tutorial.digit100_1_mc = Tutorial.kusudama_renda_counter_mc:GetChildMc("digit100_1",true)
	Tutorial.digit100_2_mc = Tutorial.kusudama_renda_counter_mc:GetChildMc("digit100_2",true)
	Tutorial.digit100_3_mc = Tutorial.kusudama_renda_counter_mc:GetChildMc("digit100_3",true)

	Tutorial.digit1_1_mc:SetVisible(false)
	Tutorial.digit10_1_mc:GotoAndPlay("number_0")
	Tutorial.digit10_2_mc:GotoAndPlay("number_1")
	Tutorial.digit100_1_mc:SetVisible(false)
	Tutorial.digit100_2_mc:SetVisible(false)
	Tutorial.digit100_3_mc:SetVisible(false)
	
	-- 2pを消す
	Debug.PrintString("2p")
	Tutorial.kusudama_root_mc_:GetChildMc("don_player2",true):SetVisible(false)
	Tutorial.kusudama_success_high_mc:GetChildMc("don_player2",true):SetVisible(false)
	Tutorial.kusudama_success_low_mc:GetChildMc("don_player2",true):SetVisible(false)
	Tutorial.kusudama_miss_mc:GetChildMc("don_player2",true):SetVisible(false)
	Debug.PrintString("2p end")
end

function tutorial_kusudama_start()
	-- 開始
	Debug.PrintString("kusudama start")
	Tutorial.kusudama_frame = 0
	Tutorial.kusudama_isActive = true
	Tutorial.kusudama_root_mc_:GotoAndPlay("start")
	Tutorial.kusudama_hit_mc:GotoAndPlay("geki_05")
	Debug.PrintString("kusudama end")
end

function tutorial_kusudama_Update(flame)
	-- 連打テキスト開始中
	if Tutorial.kusudama_isActive then
		-- Root開始時のフレーム数
		Tutorial.kusudama_frame = Tutorial.kusudama_frame + 1
		
		-- 26フレーム後に連打テキスト開始
		if Tutorial.kusudama_frame == 26 * Tutorial.fps_num then
			Tutorial.kusudama_rendas_text_mc:GotoAndPlay("init")
		end

		-- geki04
		if flame == 771 * Tutorial.fps_num then
			Tutorial.digit1_1_mc:SetVisible(true)
			Tutorial.digit1_1_mc:GotoAndPlay("number_9")
			
			Tutorial.digit10_1_mc:SetVisible(false)
			Tutorial.digit10_2_mc:SetVisible(false)
			Tutorial.kusudama_hit_mc:GotoAndPlay("geki_04")
		end

		if flame == 781 * Tutorial.fps_num then Tutorial.digit1_1_mc:GotoAndPlay("number_8") end

		-- geki03
		if flame == 791 * Tutorial.fps_num then
			Tutorial.digit1_1_mc:GotoAndPlay("number_7")
			Tutorial.kusudama_hit_mc:GotoAndPlay("geki_03")
		end

		if flame == 801 * Tutorial.fps_num then Tutorial.digit1_1_mc:GotoAndPlay("number_6") end

		-- geki02
		if flame == 811 * Tutorial.fps_num then
			Tutorial.digit1_1_mc:GotoAndPlay("number_5")
			Tutorial.kusudama_hit_mc:GotoAndPlay("geki_02")
		end

		if flame == 821 * Tutorial.fps_num then Tutorial.digit1_1_mc:GotoAndPlay("number_4") end

		-- geki01
		if flame == 831 * Tutorial.fps_num then
			Tutorial.digit1_1_mc:GotoAndPlay("number_3")
			Tutorial.kusudama_hit_mc:GotoAndPlay("geki_01")
		end

		if flame == 841 * Tutorial.fps_num then Tutorial.digit1_1_mc:GotoAndPlay("number_2") end

		-- geki00
		if flame == 851 * Tutorial.fps_num then
			Tutorial.digit1_1_mc:GotoAndPlay("number_1")
			Tutorial.kusudama_hit_mc:GotoAndPlay("geki_00")
		end

		if flame == 861 * Tutorial.fps_num then
			Tutorial.kusudama_hit_mc:SetVisible(false)
			Tutorial.kusudama_success_high_mc:GotoAndPlay("start")
			Tutorial.kusudama_root_mc_:GotoAndPlay("success_high")
		end

		-- 終了
		if flame == 926 * Tutorial.fps_num then
			Tutorial.kusudama_root_mc_:SetVisible(false)
		end
	end

	-- scene08の752フレーム目でくす玉開始
	if flame == 752 * Tutorial.fps_num then
		--くす玉開始
		tutorial_kusudama_start()
	end
end