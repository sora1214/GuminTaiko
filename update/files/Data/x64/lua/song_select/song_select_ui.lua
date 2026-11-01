-- 曲選択画面.UI表示クラスLua
-- Masayuki_Teraoka@al.bandainamco.jp

SongSelectUi = {}
function SongSelectUi.New(InstanceName_1, InstanceName_2)
	return
	{
		instance_name_1 = InstanceName_1,
		instance_name_2 = InstanceName_2,
		
		--　ロード
		LoadMovieUi = function(this)
			Lumen.LoadMovie("lumen/000_default/enso_normal/song_select/song_select_number_of_songs",this.instance_name_1)
			Lumen.LoadMovie("lumen/000_default/common/control_guide",this.instance_name_2)
			
		end,
		
		--　セットアップ
		SetupUi = function(this)
			if (Lumen.IsLoadMovieFinish() == true) then
				-- ムービークリップ取得
				this.mc_number_of_songs 	= Lumen.GetMovieClip(this.instance_name_1,true)
				this.mc_control_guide 		= Lumen.GetMovieClip(this.instance_name_2,true)
			end
		end,
		
		--　何曲目かの表示
		InitNumberOfSongs = function(this)
			this.mc_number_of_songs:SetText("main/number_of_songs","text_total_songs","attract_numberofstage")
			this.mc_number_of_songs:SetText("main/number_of_songs","text_current_songs","attract_numberofsong")
		end,
		
		--　操作ガイドの流し込み
		SetTextControlGuide = function(this)
			this.mc_control_guide.main.taiko_small.all:SetText("guide_text_instance","text_guide","decide")
			this.mc_control_guide.main.taiko_small.decide:SetText("guide_text_instance","text_guide","decide")
			this.mc_control_guide.main.taiko_large.decide:SetText("guide_text_instance","text_guide","decide")
			this.mc_control_guide.main.large_base:SetText("text_title","text_title","guide_title")
		end,
		
		--　操作ガイドの開始
		StartControlGuide = function(this)
			this.mc_control_guide:GotoAndPlay("start")		
		end,
		
		--　大きい操作ガイドの表示開始
		StartCenterControlGuide = function(this)
			Debug.PrintString("StartCenterControlGuide   ----------------------------")
			this.mc_control_guide:GotoAndPlay("main","to_center")
		end,
		
		--　通常サイズの操作ガイドの表示開始
		StartDefaultControlGuide = function(this)
			Debug.PrintString("StartDefaultControlGuide   ----------------------------")
			this.mc_control_guide:GotoAndPlay("main","to_default")
		end,
		
		--　操作ガイドのVisibleセット
		SetVisibleControlGuide = function(this, visibleflag_)
			this.mc_control_guide:SetVisible(visibleflag_)
		end,
		
	}
end

