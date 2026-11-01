-- 操作ガイド
ControlGuide = {}
function ControlGuide.New(InstanceName)
	return
	{
		instance_name_ = InstanceName,
		is_center_ = false,
		counter_ = 0,

		LoadMovie = function(this)
			Lumen.LoadMovie("lumen/000_default/common/control_guide",this.instance_name_)
		end,
		-- 初期化
		Setup = function(this)
			if (Lumen.IsLoadMovieFinish() == true) then
				-- ムービークリップ取得
				this.mc_ = Lumen.GetMovieClip(this.instance_name_,true)

				-- テキスト設定しちゃう
				this.mc_.main.taiko_small.all:SetText("guide_text_instance","text_guide","decide")
				this.mc_.main.taiko_small.decide:SetText("guide_text_instance","text_guide","decide")
-- メモ 2020.01.31 Shusuke Miura taiko_large.allにはguide_text_instanceがないので削除しました。
--				this.mc_.main.taiko_large.all:SetText("guide_text_instance","text_guide","decide")
				this.mc_.main.taiko_large.decide:SetText("guide_text_instance","text_guide","decide")
			end
		end,
		-- 表示ON/OFF
		SetVisible = function(this,flag)
			this.mc_:SetVisible(flag)
		end,
		-- 開始
		Start = function(this,mode)
			this.counter_ = 0
			this.is_center_ = false
			this.mc_:GotoAndPlay("start")
			this.mc_.main:GotoAndStop("default")

			this:ChangeMode(mode)
		end,
		-- 出る
		OutSide = function(this)
			this.mc_:GotoAndPlay("outside")
		end,
		-- 入る
		InSide = function(this)
			this.mc_:GotoAndPlay("inside")
		end,
		-- 再生中？
		IsPlay = function(this)
			return this.mc_:IsPlay()
		end,
		-- モード変更
		ChangeMode = function(this,mode)
			if(mode == 0) then
				-- 選択もある
				this.mc_.main.taiko_small:GotoAndStop("all")
				this.mc_.main.taiko_large:GotoAndStop("all")
			else
				-- 決定のみ
				this.mc_.main.taiko_small:GotoAndStop("decide")
				this.mc_.main.taiko_large:GotoAndStop("decide")
			end
		end,
		-- 更新
		Update = function(this,input)
			-- 入力があったらカウント0にする
			if(input == true) then
				this.counter_ = 0

				if(this.is_center_ == true) then
					-- 端・小モードに戻す
					this.is_center_ = false
					this.mc_.main:GotoAndPlay("to_default")
				end
			end
			-- カウントする
			if(this.is_center_ == false) then
				this.counter_ = this.counter_ + 1
				if(this.counter_ > (Common.FPS * 3)) then
					-- 中央・大モードにする
					this.is_center_ = true
					this.mc_.main:GotoAndPlay("to_center")
				end
			end
		end,
	}
end

