-- 段位選択画面.段位選択シーケンスLua
-- Masayuki_Teraoka@al.bandainamco.jp

DaniSelectDaniMain = {}
-- 使うクラスを読み込む
require("common.Sound")
require("dani_select.dani_select_theme_disp_data")

-- このクラス
function DaniSelectDaniMain.New(timer_set)
	return
	{
		State_           = State.New("DaniSelectDaniMain"),	-- このクラス用のStateクラスを作成
		
		mc_main,					-- root/main インスタンスのムービークリップを入れる
		kKanbanMoveRight = 1,		-- 右カツを入力した時の段位看板
		kKanbanMoveLeft	 = 2,		-- 左カツを入力した時の段位看板
		
		-- 各段位に対応したラベル名のテーブル
		tbl_DaniKanbanMoveLabel 	  = {"5kyuu", "4kyuu","3kyuu","2kyuu","1kyuu","1dan","2dan","3dan","4dan","5dan",
										 "6dan","7dan","8dan","9dan","10dan","11dan","12dan","13dan","14dan","gaiden"},
										 
		-- お題パネルを切り替える時のラベル名のテーブル
		tbl_DaniDetailKanbanMoveLabel = {"move_right", "move_left"},
		
		-- 各段位の適用状況テーブル(ここでfalseにした段位は選択が出来ない)
		tbl_Is_applyDaniKanban 	 	  = {true, true, true, true, true, true, true, true, true, true,
										 true, true, true, true, true, false, false, false, false, false},
		
		-- 各段位の合格状況を示すスタンプのラベル名のテーブル
		tbl_DaniKanbanStampLabel	= {"none", "none", "stamp_red_01", "stamp_red_02", "stamp_red_03", "stamp_gold_01", "stamp_gold_02", "stamp_gold_03"},
		
		mc_DaniDetailkanban_ 		= {},				-- 段位お題看板のムービークリップを入れる
		
		start_slidein_panel_cnt = 0,					-- 合格スタンプが表示されてからのカウント
		wait_slidein_cnt 		= 1.0 * Common.FPS,		-- 合格スタンプが表示されてからお題のパネルがスライドするまでのウェイト

		start_input_cnt 		= 0,					-- 最後のカツ入力が入ってからのカウント
		wait_input_cnt			= 0.1 * Common.FPS,		-- ここの値を変えることでキー入力の受付間隔を変更
		
		stay_cnt				= 0,					-- フォーカスを動かした直後からのカウント
		wait_stay_cnt 			= 0.5 * Common.FPS,		-- フォーカスを移動後ここの秒数に達するとcursorMoveFlagをfalseに変更
		
		start_wait_se_cnt 		= 0,					-- 段位板が上から落ちた時のSEが鳴ってからのカウント
		wait_se_cnt 			= 0.05 * Common.FPS,	-- この秒数を切り替えることで段位板の鳴るSEの間隔が変わる

		start_wait_request_cnt 	= 0,					-- フォーカスを動かしてからのカウント
		wait_request_cnt 		= 2.0 * Common.FPS,		-- この秒数を切り替えることで、ベストスコアのリクエストを掛けるまでの間隔が変わる
		
		INPUT_1P_LEFT			= 1,					-- プレイヤー/左カツ
		INPUT_1P_RIGHT			= 2,					-- プレイヤー/右カツ
		INPUT_1P_DECIDE			= 3,					-- プレイヤー/ドン
		INPUT_2P_LEFT			= 4,					-- プレイヤー/左カツ
		INPUT_2P_RIGHT			= 5,					-- プレイヤー/右カツ
		INPUT_2P_DECIDE			= 6,					-- プレイヤー/ドン
		
		kPanelNum				= 2,					-- 画面に表示するお題パネルの最大数
		
		kResultWaiting			= 1,					-- 開始待機
		kResultRunning			= 2,					-- 実行中
		kResultCanseled			= 3,					-- キャンセルされた（モード選択に戻る）
		kResultDecided			= 4,					-- 決定された（難易度選択へ進む）
		
		kHighestDaniLevel		= 19,					-- 最高段位の値
		scrollDirection 		= 0,					-- スクロール方向(-1が左、1が右)
		
		resultType 				= kResultWaiting,		-- 決定した結果
		
		currentDaniIndex 		= 1,					-- 選択中の段位Index
		
		cursorMoveFlag 			= false,				-- カーソルを動かしたか
		is_setUpAllOk			= false,            	-- 各種演出を含めてセットアップが終わったか
		is_openGaiden 			= false,            	-- 外伝お題を展開したか（ローンチ時未使用）
		is_timeUp				= false,            	--　お題選択中にタイムアウトしたか
		is_inputEnable 			= false,            	-- 入力受付可能フラグ
		is_timeUpEnable			= true,             	-- タイムアウト可能フラグ
		is_loopFlag 			= false,            	-- 端から端までカーソルがループしたか
		is_bestScoreRequest		= false,            	-- ベストスコアのリクエストをしたか
		is_bestScoreSubRequest	= false,				-- ベストスコアのリクエスト保険用
		
		Init = function(this)

			-- 各種セットアップ(お題の中身表示用クラスの作成)
			this.State_.func_["Begin"] = function()
				-- 各種パーツ読み込み
				Debug.PrintString("[DaniSelectMain] SequenceStart_Begin")

				this.mc_DaniDetailkanban_ = {}
				
				for idx = 1, this.kPanelNum do
					this.mc_DaniDetailkanban_[idx] = {}
					this.mc_DaniDetailkanban_[idx] = DaniDispData.New(Lumen.GetMovieClip("main/board_detail_"..idx,true))
				end
				
				this.State_:SetState("Loading")
			end
			
			-- 各種表示物のイニシャライズ
			this.State_.func_["Loading"] = function()
				Debug.PrintString("[DaniSelectMain] SequenceStart_Loading")

				if (Lumen.IsLoadMovieFinish() == true) then
					-- ムービークリップ取得
					this.mc_main = Lumen.GetMovieClip("main",true)
					
					this:OpenDaniForPlayerLevel()
					
					this:SetDefaultCurrentDani()
					
					this:RequestDaniBestScore()
					
					-- お題の表示開始フラグをC++側に伝える
					globalCursorFlag = true
					
					this:SetDaniDataAll(true, 1)
					this:ChangeDaniBoardStamp(true)
					
					this:GrayOutDaniBoard()
					
					this.mc_main:GotoAndPlay("in")
					
					-- 上から落ちてくる段位看板の演出開始
					this.mc_main.board_all.normal:GotoAndPlay("in_board")
					
					this:StartDaniBoardStamp()
					
					this.State_:SetState("BoardWait")
				end
			end
			
			-- 再度シーケンスが戻った時用
			this.State_.func_["ReLoading"] = function()
				if (Lumen.IsLoadMovieFinish() == true) then
					
					this.State_:SetState("Main")
				end
			end
			
			-- 上から降ってくる段位看板の演出
			this.State_.func_["BoardWait"] = function()
				
				if (this:waitSeCnt() == true) then
					TSound:Play("se_daniodai_v12e", "fuda")
				end
				
				-- 演出が終わったら次のシーケンスへ遷移
				if(this.mc_main.board_all.normal:IsPlay() == false) then
				
					-- 合格スタンプが一個でもあればSEを鳴らす
					if (this:IsDaniBoardStamp() == true) then 
						TSound:Play("se_daniodai_v12e", "stamp") 
					end
					
					this.State_:SetState("SlideInWait")
				end
			end
			
			-- お題パネルスライドインの演出開始まで
			this.State_.func_["SlideInWait"] = function()
				
				-- 既定のフレームカウントが完了したか、合格スタンプが一個も無い場合
				if(this:waitSlideInCnt() == true or this:IsDaniBoardStamp() == false) then
				
					-- お題パネルスライドイン
					this.mc_main:GotoAndPlay("in_left")
					TSound:Play("se_daniodai_v12e", "plate")
					
					-- どんちゃんスライドイン
					this.mc_main.don_1p:GotoAndPlay("framein")
					
					TSound:Play("voice_daniodai_v12e", "odai_choose")
					
					this.is_setUpAllOk = true
					
					this.State_:SetState("QuotaBoardWait")
				end
			end
			
			-- お題パネルスライドイン中
			this.State_.func_["QuotaBoardWait"] = function()
				
				-- スライドインの演出が終わったらシーケンスを遷移
				if(this.mc_main:IsPlay() == false) then
					
					-- C++ 側にQRコードアイコンの表示OKフラグを知らせる
					QRCodeDispEnable = true
					
					-- 段位選択選択BGM
					TSound:PlayBGM("bgm_daniodai_v12e")
					
					-- 初期カーソル位置のアニメーション開始
					this.mc_main.board_all.normal:GotoAndPlay(this.tbl_DaniKanbanMoveLabel[this.currentDaniIndex])
					
					this.State_:SetState("Main")
				end
			end
			
			-- メインシーケンス
			this.State_.func_["Main"] = function()

				-- プレイヤーの入力
				this:PlayerInput()
				
				-- 一定のフレームで入力受付可能フラグ建てる
				if (this:waitInputCnt() == true) then
					this:SetInputEnable(true)
				end
				
				-- ベストスコアの処理を回す
				this:BestScoreMain()
				
			end
			
			-- 終了シーケンス
			this.State_.func_["End"] = function()
				
				this:SetResultType(this.kResultDecided)
				
			end
		end,
		
	-- ここまでInit
		
		-- キー入力が可能になるまでのカウント
		waitInputCnt = function(this)
			this.start_input_cnt = this.start_input_cnt +1
			
			if (this.start_input_cnt >= this.wait_input_cnt) then
				this.start_input_cnt = 0
				return true
			else return false
			end
		end,
		
		-- お題のパネルをスライドさせるまでのカウント
		waitSlideInCnt = function(this)
			this.start_slidein_panel_cnt = this.start_slidein_panel_cnt +1
			
			if (this.start_slidein_panel_cnt >= this.wait_slidein_cnt) then
				this.start_slidein_panel_cnt = 0
				return true
			else return false
			end
		end,
		
		-- 段位看板が落ちてくる際のSEを鳴らす間隔のカウント
		waitSeCnt = function(this)
			this.start_wait_se_cnt = this.start_wait_se_cnt +1
			
			if (this.start_wait_se_cnt >= this.wait_se_cnt) then
				this.start_wait_se_cnt = 0
				return true
			else return false
			end
		end,
		
		-- ベストスコアのリクエストを掛けるまでのカウント
		waitRequestCnt = function(this)
			this.start_wait_request_cnt = this.start_wait_request_cnt +1
			
			if (this.start_wait_request_cnt >= this.wait_request_cnt) then
				this.start_wait_request_cnt = 0
				return true
			else return false
			end
		end,

		-- ステートを更新
		Update = function(this)
			this.State_:Update()
		end,
		
	-- ここまでUpdate
		
		-- 再度シーケンスが戻った時用
		ReStartDaniSelect = function(this)
			this.State_:SetState("ReLoading")
		end,
		
		-- 外伝お題を展開したとき用(ローンチ未使用)
		OpenGaidenList = function(this)
			this.State_:SetState("OpenFolderState")
		end,
		
		-- 外伝お題をクローズしたとき用(ローンチ未使用)
		CloseGaidenList = function(this)
			this.State_:SetState("CloseFolderState")
		end,
			
		-- プレイヤーの入力
		PlayerInput = function(this)
		
			-- キー入力
			if ((this:CheckInput() == this.INPUT_1P_DECIDE or this:CheckInput() == this.INPUT_2P_DECIDE) or this.is_timeUp == true) then
				-- 面
				
				this:PlaySeDon()
				this.State_:SetState("End")
				
			elseif (this:CheckInput() == this.INPUT_1P_RIGHT or this:CheckInput() == this.INPUT_2P_RIGHT) then
				if (this:GetDaniPanelNum() > 1) then 
					Debug.PrintString("TriggeredRight")
					-- 右ふち
					-- 段位看板のフォーカスを右へ移動
					this:PlaySeKatsu()				
					this:MoveCursor(1, true)
				end
			elseif (this:CheckInput() == this.INPUT_1P_LEFT or this:CheckInput() == this.INPUT_2P_LEFT) then
				if (this:GetDaniPanelNum() > 1) then 
					Debug.PrintString("TriggeredLeft")
					-- 左ふち
					-- 段位看板のフォーカスを左へ移動
					this:PlaySeKatsu()								
					this:MoveCursor(-1, true)
				end
			end

		end,
		
		-- 上下入力
		MoveCursor = function(this, direction, timeUp)
		
			this:SetInputEnable(false)
			
			this.is_loopFlag = false
			this:SetMoveFlag(true)
			this.scrollDirection = direction;
			
			-- 移動方向によって提灯と曲のindexの対応テーブルを切り替え、アニメさせる
			if (this.scrollDirection < 0) then
				this.mc_main:GotoAndPlay(this.tbl_DaniDetailKanbanMoveLabel[this.kKanbanMoveRight])
			else 
				this.mc_main:GotoAndPlay(this.tbl_DaniDetailKanbanMoveLabel[this.kKanbanMoveLeft])
			end
			
			this:MoveDaniKanbanLabel()
			
			this:ChangeDani(this.currentDaniIndex)
			
			this.stay_cnt = 0
			
			this:SetDaniDataAll(false, this.scrollDirection)
			--this:RequestDaniBestScore()
			this:ChangeDaniBoardStamp(false)
		end,
		
		
		-- 段位看板のフォーカスを切り替える
		MoveDaniKanbanLabel = function(this)
			
			-- 切り替え方向によって、有効な段位を検索しIndexを切り替える
			if (this.scrollDirection < 0) then
				this:LeftSearchNextEnableDani(this.currentDaniIndex)
			else
				this:RightSearchNextEnableDani(this.currentDaniIndex)
			end
			
			-- 現在フォーカスしている段位看板のアニメーションを開始
			this.mc_main.board_all.normal:GotoAndPlay(this.tbl_DaniKanbanMoveLabel[this.currentDaniIndex])

		end,
		
		-- 右カツの時の有効な段位看板の検索
		RightSearchNextEnableDani = function(this, currentDaniIndex)
			
			local is_findRight = false
			
			-- 右方向から調べる
			for idx = currentDaniIndex + 1, #this.tbl_DaniKanbanMoveLabel do
				if (this.tbl_Is_applyDaniKanban[idx] == true) then
					is_findRight = true
					this.currentDaniIndex = idx
					return
				end
			end
			
			-- 左方向から調べる
			if (is_findRight == false) then
				for idx = 1, currentDaniIndex - 1 do
					if (this.tbl_Is_applyDaniKanban[idx] == true) then
						this.currentDaniIndex = idx
						this.is_loopFlag = true
						return
					end
				end
			end
		end,
		
		-- 左カツの時の有効な段位看板の検索
		LeftSearchNextEnableDani = function(this, currentDaniIndex)
			
			local is_findLeft = false
			
			-- 左方向から調べる
			for idx = currentDaniIndex -1, 1, -1 do
				if (this.tbl_Is_applyDaniKanban[idx] == true) then
					is_findLeft = true
					this.currentDaniIndex = idx
					return
				end
			end
			
			-- 右方向から調べる
			if (is_findLeft == false) then
				for idx = #this.tbl_DaniKanbanMoveLabel, currentDaniIndex + 1, -1 do
					if (this.tbl_Is_applyDaniKanban[idx] == true) then
						this.currentDaniIndex = idx
						this.is_loopFlag = true
						return
					end
				end
			end
		end,
		
		-- プレイヤーの初期カーソル位置を決める
		SetDefaultCurrentDani = function(this)
			
			local maxDani
			
			-- 無効な段位を検索し最高段位を取得する
			for idx = 1, #this.tbl_Is_applyDaniKanban do
				if (this.tbl_Is_applyDaniKanban[idx] == false) then
					maxDani = idx
					break
				end
			end
			
			-- 現在のインデックスにプレイヤーの取得段位+１の値を入れる
			this.currentDaniIndex = playerNowRank + 1
			
			-- もしプレイヤーが既に有効な最高段位を取得している場合には最高段位から-1した値を入れる
			if (this.currentDaniIndex >= maxDani) then
				this.currentDaniIndex = maxDani - 1
			end
			
			daniId = this.currentDaniIndex
			
		end,
		
		-- プレイヤーの到達段位で段位を解放
		OpenDaniForPlayerLevel = function(this)
		
			for idx = 1, playerNowRank do
				if (idx == this.kHighestDaniLevel) then
					return
				else
					if ((idx + 1) <= DaniNum) then
						this.tbl_Is_applyDaniKanban[idx + 1] = true
					else
						return
					end
				end
			end
		end,
		
		--有効な段位の種類数
		GetDaniPanelNum = function(this)
			return DaniNum
		end,
		
		-- インデックスから該当する段位のデータを取得する
		GetPanelData = function(this, daniIndex)
			index = daniIndex
			
			if (index <= 0) then
				index = this:GetDaniPanelNum()
			end
			
			return daniData[index]
			
		end,
		
		-- プレイヤーが一個でも段位を合格しているか
		IsDaniBoardStamp = function(this)

			for i = 1, DaniNum do
				if (daniData[i].clear_level >= DaniClearRank.kRedClear) then
					return true
				end
			end
			
			return false
		end,
		
		-- フォーカスしている段位に内部データを変更する
		ChangeDani = function(this, index)
			this:UpdateDaniChoise(index)
		end,
		
		--すべての板に段位を設定する.
		SetDaniDataAll = function(this, initFlag, direction)
			Debug.PrintString("SetDaniDataAll")
			
			-- 端から端までループする場合
			if (this.is_loopFlag == true) then
				if (direction > 0) then
					-- 右入力で左端にループする場合、左に消えていく段位（有効な段位）をセット
					DaniData_plus = this:GetPanelData(this:SearchLeftApplyDaniIdx())
				else
					-- 左入力で右端にループする場合、右に消えていく段位（有効な段位）をセット
					DaniData_minus = this:GetPanelData(1)						
				end
			--	ループではない通常の場合
			else
				-- 1個上の段位をセット
				DaniData_plus = this:GetPanelData(this.currentDaniIndex +1)
				-- 1個下の段位をセット
				DaniData_minus = this:GetPanelData(this.currentDaniIndex -1)			
			end
			
			-- 現在フォーカスしようとしている段位をセット
			DaniData = this:GetPanelData(this.currentDaniIndex)
			
			-- 初回起動の場合か否か
			if (initFlag == false) then
				this.mc_DaniDetailkanban_[1]:SetDaniData(DaniData)
			else
				this.mc_DaniDetailkanban_[2]:SetDaniData(DaniData)
				return
			end
			
			-- 消えていく段位の表示処理（右入力）
			if (direction > 0) then
				-- ループする場合
				if (this.is_loopFlag == true) then
					this.mc_DaniDetailkanban_[2]:SetDaniData(DaniData_plus)
				else
					this.mc_DaniDetailkanban_[2]:SetDaniData(DaniData_minus)
				end
				
			-- 消えていく段位の表示処理（左入力）	
			else
				-- ループする場合
				if (this.is_loopFlag == true) then
					this.mc_DaniDetailkanban_[2]:SetDaniData(DaniData_minus)
				else
					this.mc_DaniDetailkanban_[2]:SetDaniData(DaniData_plus)
				end				
			end
			
		end,
		
		-- Mainで回す各種ベストスコア処理
		BestScoreMain = function(this)
			
			-- 移動フラグが建ったらベストスコアのリクエストを掛ける
			if (this:GetMoveFlag() == true) then
				this:RequestDaniBestScore()
			end
			
			-- 上記のリクエストで取得できなかった時は、再度リクエストを掛ける
			if (this:waitRequestCnt() == true and this:GetMoveFlag() == false and this.is_bestScoreSubRequest == true) then
				this.is_bestScoreSubRequest = false
				this:RequestDaniBestScore()
			end
			
			-- 一定のフレームでベストスコアの値を更新する
			if (this:StayCount() == true) then
				this:SetDaniBestScore()
			end

		end,
		
		-- 段位のベストスコアをGSにリクエストする
		RequestDaniBestScore = function(this)
			is_userDataUpdate = false
			this.is_bestScoreRequest = false
			
			DaniData = this:GetPanelData(this.currentDaniIndex)
			
			if (DaniData.clear_level > DaniClearRank.kNoPlay and DaniData.is_bestscore_get == false) then
				this.is_bestScoreRequest = true
				
				if (is_joinPlayer[1] == true) then
					NetAccess.GetDaniScore(0, this.currentDaniIndex)
				else
					NetAccess.GetDaniScore(1, this.currentDaniIndex)
				end
			end
		end,
		
		-- 段位のベストスコアを設定する
		SetDaniBestScore = function(this)
			Debug.PrintString("SetDaniBestScore")
			DaniData = this:GetPanelData(this.currentDaniIndex)
			
			-- リクエストがされていて、ユーザーデータが更新している or 既に一度表示をしているなら
			if ((is_userDataUpdate == true and this.is_bestScoreRequest == true) or DaniData.is_bestscore_get == true) then
				-- ベストスコアのセットに問題が発生した場合再度リクエストを掛けるフラグを建てる
				if (DaniData:SetDaniBestScore() == false) then
					this.is_bestScoreSubRequest = true
					return
				else
					this.mc_DaniDetailkanban_[2]:UpdateBestDaniScore(DaniData)
					this.mc_DaniDetailkanban_[1]:UpdateBestDaniScore(DaniData)				
				end
			else
				this.is_bestScoreSubRequest = true
			end
	
		end,
		
		-- 左カツで終わり側から有効なidxを返す
		SearchLeftApplyDaniIdx = function(this)
			-- 右方向から調べる
			for idx = #this.tbl_DaniKanbanMoveLabel, 1, -1 do
				if (this.tbl_Is_applyDaniKanban[idx] == true) then
					return idx
				end
			end
		end,
		
		-- 段位の選択状態を更新
		UpdateDaniChoise = function(this, daniIndex)
			
			data = this:GetPanelData(daniIndex)
			
			if (data.dani_level <= 19) then
				daniId = daniIndex
			end			
		end,
		
		-- 段位板のグレーアウト切り替え
		GrayOutDaniBoard = function(this)
			
			for idx = 1, #this.tbl_DaniKanbanMoveLabel do
				if (this.tbl_Is_applyDaniKanban[idx] == false) then
					this.mc_main:GotoAndStop("board_all/normal/board_"..idx, "lock")
				else
					this.mc_main:GotoAndStop("board_all/normal/board_"..idx, "init")
				end
			end
		end,
		
		-- 段位板の合格印の切り替え及び表示開始
		StartDaniBoardStamp = function(this)
			
			for idx = 1, DaniNum do
				this.mc_main:GotoAndStop("board_all/normal/stamp_"..idx.."/middle_stamp_anime_1", this.tbl_DaniKanbanStampLabel[daniData[idx].clear_level + 1])
				this.mc_main:GotoAndStop("board_all/normal/stamp_"..idx.."/middle_stamp_anime_2", this.tbl_DaniKanbanStampLabel[daniData[idx].clear_level + 1])
				this.mc_main:GotoAndPlay("board_all/normal/stamp_"..idx.."", "in_stamp")
			end
		end,
		
		-- お題ボードの合格印の切り替え
		ChangeDaniBoardStamp = function(this, initFlag)
		
			if (initFlag == false) then
				this.mc_main.stamp_detail_1:GotoAndStop(this.tbl_DaniKanbanStampLabel[daniData[this.currentDaniIndex].clear_level + 1])
			else
				this.mc_main.stamp_detail_2:GotoAndStop(this.tbl_DaniKanbanStampLabel[daniData[this.currentDaniIndex].clear_level + 1])				
			end
		end,

		-- 実行状態を取得する
		GetResult = function(this)
			return this.resultType
		end,
		
		-- 実行状態をセットする
		SetResultType = function(this, type)
			this.resultType = type
		end,
		
		-- 外伝の開閉状態を取得する(ローンチ時未使用)
		GetOpenGaiden = function(this)
			return this.is_openGaiden
		end,
		
		-- 外伝の開閉状態をセットする(ローンチ時未使用)
		SetOpenGaiden = function(this, setFlag)
			this.is_openGaiden = setFlag
		end,
		
		-- カーソル移動フラグを取得する
		GetMoveFlag = function(this)
			return this.cursorMoveFlag
		end,

		-- カーソル移動フラグをセットする
		SetMoveFlag = function(this, setFlag)
			this.cursorMoveFlag = setFlag
			globalCursorFlag = setFlag
		end,
		
		-- カレントインデックスをセットする
		SetCurrentDaniIndex = function (this, index)
			this.currentDaniIndex = index
		end,
		
		-- フォーカス位置に留まっているフレームが一定値を越えたらフラグが建つ
		StayCount = function(this)
		
			this.stay_cnt = this.stay_cnt +1
			
			if (this.stay_cnt >= this.wait_stay_cnt) then
				this:SetMoveFlag(false)
				this.stay_cnt = 0
				return true
			end
			
			return false
		end,
		
		-- プレイヤーの入力受付可能かのフラグを取得する
		GetInputEnable = function(this)
			return this.is_inputEnable
		end,
		
		-- プレイヤーの入力受付可能かのフラグをセットする
		SetInputEnable = function(this, setFlag)
			this.is_inputEnable = setFlag
		end,
		
		-- タイムアップ時の動作開始ウェイト
		WaitCountTimeUpMove = function(this)

			this.timeup_start_cnt = this.timeup_start_cnt + 1
			
			if (this.timeup_start_cnt >= this.wait_timeup_move_cnt) then
				this.timeup_start_cnt = 0
				return true
			else return false
			
			end
		end,
		
		-- プレイヤーの入力状況をチェック
		CheckInput = function(this)
			
			if (this:GetInputEnable() == true) then
			
				if(is_joinPlayer[1] == true) then
					-- 1Pの入力
					if (this:GetMoveFlag() == false) then 
						if (Input.GetTrigger(Input.PLAYER1_OK) or Input.GetTrigger(Input.PLAYER1_CANCEL)) then 
						return this.INPUT_1P_DECIDE 
						end
					end
					if (Input.GetTrigger(Input.PLAYER1_LEFT))	then return this.INPUT_1P_LEFT end
					if (Input.GetTrigger(Input.PLAYER1_RIGHT))	then return this.INPUT_1P_RIGHT end
				end
				
				if(is_joinPlayer[2] == true) then
					-- 2Pの入力
					if (this:GetMoveFlag() == false) then 
						if (Input.GetTrigger(Input.PLAYER2_OK) or Input.GetTrigger(Input.PLAYER2_CANCEL)) 
						then return this.INPUT_2P_DECIDE 
						end
					end
					if (Input.GetTrigger(Input.PLAYER2_LEFT))	then return this.INPUT_2P_LEFT end
					if (Input.GetTrigger(Input.PLAYER2_RIGHT))	then return this.INPUT_2P_RIGHT end
				end
			end
		end,
		
		-- どんSEをエントリーによって鳴らす
		PlaySeDon = function(this)
			TSound:Play("se_common_v12a","don_c")
		end,
		
		-- カツSEをエントリーによって鳴らす
		PlaySeKatsu = function(this)
			TSound:Play("se_common_v12a","katsu_c")
		end,
		
		-- タイムアウトフラグを建てる
		TimeUpBegin = function(this)			
			this.is_timeUp = true
		end,
		
	}
end