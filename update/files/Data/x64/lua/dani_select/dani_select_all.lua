-- 段位選択画面.全体シーケンスLua
-- Masayuki_Teraoka@al.bandainamco.jp

-- 使うクラスを読み込む
require("common.NamePlate")
require("common.Sound")
require("common.State")
require("common.Timer")

require("dani_select.dani_select_introduction_main")
require("dani_select.dani_select_confirmation_main")
require("dani_select.dani_select_dani_main")
require("dani_select.dani_select_option_main")
require("dani_select.DaniData")

-- このクラス
DaniSelectAllMain = {

	AllState_      = State.New("DaniSelectAllMain"),
	
	start_cnt      = 0,
	wait_start_cnt = 0.1 * Common.FPS,

	timer_ 		   = Timer.New("timer_instance"),			-- タイマーインスタンス
	name_plate_    = NamePlate.New("plate_1p_instance"),	-- ネームプレートインスタンス
	
	kResultWaiting			= 1,		-- 開始待機
	kResultRunning			= 2,		-- 実行中
	kResultCanseled			= 3,		-- キャンセルされた
	kResultDecided			= 4,		-- 決定された（確認画面へ進む）
	kResultGatden			= 5, 		-- 外伝の開始
	
	is_playIntroduction 	= false,	-- 導入演出を再生したかどうか
	is_daniTimeUp 			= false,    -- 段位選択時にタイムアウトになったか
	is_confirmationTimeUp 	= false,    -- 確認画面時にタイムアウトになったか
	is_createGaiden			= false,    -- 外伝段位を作成したか（ローンチ未使用）
		
	Init = function(this)

		-- ロードムービー等の準備
		this.AllState_.func_["Begin"] = function()
			-- 各種パーツ読み込み
			Debug.PrintString("[DaniSelectAllMain] SequenceStart_Begin")
			
			daniselectdani_ 	    = DaniSelectDaniMain.New(0)
			daniselectconfirmation_ = DaniSelectConfirmationMain.New(0)
			daniselectintroduction_ = DaniSelectIntroductionMain.New("introduction_instance")
			
			daniselectconfirmation_:LoadMovieConfirmationMain()
			daniselectintroduction_:LoadMovieIntroductionMain()
			
			this.timer_:LoadMovie()
			this.name_plate_:LoadMovie()
			
			this.AllState_:SetState("Loading")
			Debug.PrintString("[DaniSelectAllMain] SequenceEnd_Begin")
		end
		
		this.AllState_.func_["Loading"] = function()
		
			this.AllState_:SetState("SetUp")
			Debug.PrintString("[DaniSelectAllMain] SequenceEnd_Loading")
		end
		
		-- セットアップ
		this.AllState_.func_["SetUp"] = function()
			if (Lumen.IsLoadMovieFinish() == true) then
				
				-- タイマーの準備
				this.timer_:Setup(9)
				this.timer_:SoundSetting(true, true)
				this.timer_:SetVisible(true)
				this.timer_:SetShadow(false)
				this.timer_:SetCount(100)
				
				-- ジャンル画面のイニシャライズ
				daniselectdani_:Init()
				daniselectconfirmation_:Init()
				
				daniselectintroduction_:SetupIntroduction()
				this:InitDon3D()
				this:InitNamePlate()
				
				this:GetUserData()
				
				-- そのクレジット中で最後に設定した内容を取得する
				user_setting_Original_data_[1] = PlayDataManager.GetOriginalEnsoModeSetting(0)
				user_setting_Original_data_[2] = PlayDataManager.GetOriginalEnsoModeSetting(1)
				
				-- オプションの設定
				
				daniselectconfirmation_:SetUpDaniSelectOption()
				
				-- プレイヤーが設定したオプションを設定
				if (is_joinPlayer[1] == true) then
					daniselectconfirmation_:SetOptionLastDiff(1)
				else
					daniselectconfirmation_:SetOptionLastDiff(2)				
				end
				
				playerNowRank = play_data_.user_data.daniRecordInfo.now_dani
				
				-- オプションの初期設定
				daniselectconfirmation_:InitOptionIcon()
				
				-- C側に準備完了通知
				Common.LuaPrepareFinish()

				this.AllState_:SetState("StartWait")
				Debug.PrintString("[DaniSelectAllMain] SequenceEnd_Loading")

			end
		end
		
		-- 開始ウェイト
		this.AllState_.func_["StartWait"] = function()
		
			Debug.PrintString("[DaniSelectAllMain] SequenceStart_StartWait")
			
			if(this:waitCnt() == true) then
				
				-- カウンター開始				
				this.start_cnt = 0

				this:CreateDaniData()
				
				this.AllState_:SetState("IntroductionMain")
				
				Debug.PrintString("[DaniSelectAllMain] SequenceEnd_StartWait")
			end
		end
		
		-- 導入画面
		this.AllState_.func_["IntroductionMain"] = function()
			Debug.PrintString("[DaniSelectAllMain] SequenceStart_IntroductionMain")
			
			if (this.is_playIntroduction == false) then
				daniselectintroduction_:PlayIntroduction()
				this.is_playIntroduction = true
			end
			
			if (daniselectintroduction_:Is_EndAnimation() == true) then
				this.AllState_:SetState("DaniSelectMain")
			end

		end
		
		-- 段位選択画面
		this.AllState_.func_["DaniSelectMain"] = function()
			--Debug.PrintString("[DaniSelectMain] SequenceStart_DaniSelectMain")
			
			-- 演出を含めてセットアップが終わったらタイマーを開始
			if (daniselectdani_.is_setUpAllOk == true) then 
				this.timer_:StartCount()
				this.name_plate_:SetVisible(true)
				daniselectdani_.is_setUpAllOk = false
			end
			
			-- タイムアウト時
			if(this.timer_:IsZero() == true and daniselectdani_.is_timeUpEnable == true) then
				Debug.PrintString("[DaniSelectMain] TimeUp")
				
				this.is_daniTimeUp = true
				
				-- タイムアップシーケンスの準備
				daniselectdani_:TimeUpBegin()
				-- ＳＥ「大どん（中央）」
				TSound:Play("se_common_v12a","don_big")
			end
			
			-- C++側でベストスコアの取得が完了したらユーザーデータを更新する
			if(enableUserDataFlag == true and is_userDataUpdate == false) then
				this:GetUserData()
				enableUserDataFlag = false
				is_userDataUpdate = true
			end
			
			-- 段位選択基本シーケンスのアップデート
			daniselectdani_:Update()
			
			-- 任意に段位を選択して確認画面に遷移するとき
			if (daniselectdani_:GetResult() == this.kResultDecided) then				
				daniselectdani_:SetResultType(this.kResultRunning)
				daniselectdani_:ReStartDaniSelect()
				
				-- タイムアップになっている状態か残りタイマーが30秒以下か
				if (this.is_daniTimeUp == true or this.timer_:GetCount() < 30) then 
					this.timer_:SetCount(30)
					this.timer_:StartCount()
					
					-- 事前にタイムアップ・既定時間未満になっていることを知らせる
					daniselectconfirmation_:SetDaniTimeUpFlag(true)
				end
				
				-- 3Dドンのアニメーション
				this:DecideDonAnimation()
				
				this.AllState_:SetState("ConfirmationMain")
			end
		end
		
		-- 確認画面
		this.AllState_.func_["ConfirmationMain"] = function()
			
			-- タイムアウト時
			if(this.timer_:IsZero() == true and daniselectconfirmation_.is_timeUpEnable == true) then
				Debug.PrintString("[ConfirmationMain] TimeUp")
				
					if(daniselectconfirmation_:GetIsOption() == true)then
						-- オプションを開いている場合
						daniselectconfirmation_:TimeUpOptionSequence()
					end
				
				this.is_confirmationTimeUp = true
				
				-- 入力を切る
				daniselectconfirmation_:SetInputEnable(false)
				
				-- タイムアップシーケンスの準備
				daniselectconfirmation_:TimeUpBegin()
			end
			
			-- 段位選択確認画面シーケンスのアップデート
			daniselectconfirmation_:Update()
			
			-- 最終決定直後処理（タイマーの停止、3Dドンのアニメーション開始)
			if (daniselectconfirmation_:GetEndFlag() == true) then 
				this.timer_:StopCount()
				this:EndDonAnimation() 
				daniselectconfirmation_:SetEndFlag(false)
			end
			
			-- 挑戦しないを選択した場合、通常段位選択シーケンスへ戻る
			if (daniselectconfirmation_:GetResult() == this.kResultCanseled) then				
				daniselectconfirmation_:SetResultType(this.kResultRunning)
				daniselectconfirmation_:ReStartConfirmationSelect()
				this:ReturnDonAnimation()
				this.AllState_:SetState("DaniSelectMain")
			
			-- 最終決定後の全演出終了時
			elseif (daniselectconfirmation_:GetResult() == this.kResultDecided) then				
				this.AllState_:SetState("End")
			end

		end
		
		-- 終了シーケンス
		this.AllState_.func_["End"] = function()
			Debug.PrintString("[SongSelectAllMain] End")
			
			-- 演奏ゲームへの遷移を指定
			nextMode = SceneType.kEnsoGame
			
			-- C++ 側へ Lua 側終了の通知を送る
			Common.LuaFinish()
			
		end
	end,
	
-- ここまでDaniSelectAllInit
	
	waitCnt = function(this)
		this.start_cnt = this.start_cnt + 1
		
		if (this.start_cnt >= this.wait_start_cnt) then
			this.start_cnt = 0
			return true
		else return false
		end
	end,

	
	-- 3Dドンのイニシャライズ
	InitDon3D = function(this)
		Debug.PrintString("InitDon3D")
		
		this.don1p_ = Lumen.GetMovieClip("don_1p",true)
		this.don1p_:SetVisible(true)
		Don.SetLoopAnimation(0,"result_clear_loop",true)

		Don.ChangeDonForPlayData(0,Don.kType_Don)
		Don.CameraReverse(0,false)
	end,
	
	-- 段位選択に戻った時のどんアニメーション
	ReturnDonAnimation = function(this)
		Don.SetLoopAnimation(0,"result_clear_loop",true)
	end,

	-- 段位決定時のどんアニメーション
	DecideDonAnimation = function(this)	
		Don.SetNonLoopAnimation(0,"full_combo",true)
		Don.SetLoopAnimation(0,"balloon_loop",true)
	end,
	
	-- 確認画面決定時のどんアニメーション
	EndDonAnimation = function(this)
		Don.SetNonLoopAnimation(0,"select_out_p1",true)
	end,
	
	-- ネームプレートのイニシャライズ
	InitNamePlate = function(this)
		
		-- ネームプレートの準備
		this.name_plate_:Setup()
		this.name_plate_:SetVisible(false)
		
		if (is_joinPlayer[1] == true) then
			this.name_plate_:SetPlayerInfo(1)
		else
			this.name_plate_:SetPlayerInfo(2)
		end
	end,
	
	-- 外伝選択画面に遷移した時
	SelectGaidenBoard = function(this)
		Debug.PrintString("SelectGaidenBoard")
		
		this:CreateDaniData()
		this.is_createGaiden = true
		
	end,
	
	-- 外伝から戻った時
	ReturnNormalDaniBoard = function(this)
		Debug.PrintString("ReturnNormalDaniBoard")

		selectedSongNum = 0
		
		this:CreateDaniData()
		this.is_createGaiden = false
		
	end,
	
	-- 全段位情報を作成
	CreateDaniData = function(this)
		Debug.PrintString("CreateDaniData")

		daniData = {}
		
		for i = 1, DaniNum do
			daniData[i] = DaniData.New(i)
			daniData[i]:SetDaniInfoData()
			daniData[i]:SetMusicInfoData()
		end
	end,
	
	-- ユーザーデータを取得する
	GetUserData = function(this)
		Debug.PrintString("GetUserData")
		-- ユーザーデータ取得
		if (is_joinPlayer[1] == true) then
			play_data_ = PlayDataManager.GetEntryPlayData(0)
		else
			play_data_ = PlayDataManager.GetEntryPlayData(1)
		end
	end,
		
	-- 段位ベストスコアの準備ができているか確認
	CheckDaniDataAvailable = function(this)
		if(is_joinPlayer[1] == true) then
			if(PlayDataManager.GetDaniDataStatus(0) == UserDataStatus.kNone) then
				return UserDataStatus.kNone
			
			elseif(PlayDataManager.GetDaniDataStatus(0) == UserDataStatus.kError) then
				return UserDataStatus.kError
			end
		else
			if(PlayDataManager.GetDaniDataStatus(1) == UserDataStatus.kNone) then
				return UserDataStatus.kNone
			
			elseif(PlayDataManager.GetDaniDataStatus(1) == UserDataStatus.kError) then
				return UserDataStatus.kError
			end
		end
		
		-- 完了
		return UserDataStatus.kAvailable
	end,

	Update = function(this)
	
		-- ステート処理
		this.AllState_:Update()
		
		-- タイマー実行
		this.timer_:Update()

	end,
-- ここまでUpdate

}
-- ここまでMain