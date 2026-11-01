-- 使うクラスを読み込む
require("common.State")

-- このクラス
Main = {
	m_State = State.New("TeraokaTest"),
	m_PanelName = {"panel_1","panel_2","panel_3","panel_4","panel_5","panel_6","panel_7","panel_8","panel_9","panel_10","panel_11","panel_12","panel_13"},
	m_MainMc,
	m_PanelMc,
	m_PanelNum = 1,
	
	Init = function(this)

		-- ステートマシンを組み立てておく、実際に実行されるのはステート処理を実行するとき
		this.m_State.Func["Begin"] = function()
			-- 各種パーツ読み込み
			Lumen.LoadMovie("lumen/system/title_signage","title")

			Debug.PrintFrame()

			this.m_State:SetState("Loading")
		end
		this.m_State.Func["Loading"] = function()
			if (Lumen.IsLoadMovieFinish() == true) then
				-- ムービークリップ取得
				this.m_MainMc = Lumen.GetMovieClip("main",true)
				this.m_PanelMc = Lumen.GetMovieClip("main/panel_mc",true)		-- ルートのMCからツリーを全部書く
				
				-- ルートのMC再生
				Lumen.Play()
				-- メインMC
				this.m_MainMc:Play()

				-- タイトル設定
				this.m_PanelMc:GotoAndPlay("title_small_mc","start_title")

				this.m_State:SetState("Start")
			end
		end

		this.m_State.Func["Start"] = function()
			-- キー入力
			if (Input.GetTrigger(Input.ALLPLAYER_OK) == true) then
				-- 面
				-- パネル切り替え
				--Panel:ChangePanel(oldID,this.m_CursorPos)
				this.m_PanelNum = this.m_PanelNum + 1;
				if(this.m_PanelNum > 13) then
					this.m_PanelNum = 1
				end
				this.m_PanelMc:GotoAndStop(this.m_PanelName[this.m_PanelNum])

			elseif (Input.GetTrigger(Input.ALLPLAYER_RIGHT) == true) then
				-- 右ふち
				-- パネル切り替え
				--Panel:ChangePanel(oldID,this.m_CursorPos)
				this.m_PanelNum = this.m_PanelNum + 1;
				if(this.m_PanelNum > 13) then 
					this.m_PanelNum = 1
				end
				this.m_PanelMc:GotoAndStop(this.m_PanelName[this.m_PanelNum])

			elseif (Input.GetTrigger(Input.ALLPLAYER_LEFT) == true) then
				-- 左ふち
				-- パネル切り替え
				--Panel:ChangePanel(oldID,this.m_CursorPos)
				this.m_PanelNum = this.m_PanelNum - 1;
				if(this.m_PanelNum < 1) then
					this.m_PanelNum = 13
				end
				this.m_PanelMc:GotoAndStop(this.m_PanelName[this.m_PanelNum])
				
			end
		end
	end,
-- ここまでInit


	Update = function(this)
		-- パッドの更新

		-- ステート処理
		this.m_State:Update()
		
	end,
-- ここまでUpdate

}
-- ここまでMain