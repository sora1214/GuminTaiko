-- 曲紹介１曲分の表示
MusicIntroSongData = {}
--function MusicIntroSongData.New(InstanceName)
function MusicIntroSongData.New(iParentMc)
	return
	{
		main_mc_ = iParentMc,
		Init = function(this)
			this.genre_mc_ = this.main_mc_:GetChildMc("genre_instance",true)
			-- 子供のムービークリップ取得する
--			this.papamama_mc_ = this.main_mc_:GetChildMc("papamama_instance",true)
			-- メンバ変数みたいにして子供のムービークリップを取れる
--			this.papamama_mc_ = this.main_mc_.papamama_instance
		end,
		DispOn = function(this,musicinfo)
			this.main_mc_:SetVisible(true)

			this.main_mc_:GotoAndStop("on");

			this.main_mc_.text_instance:SetText("text_songname",musicinfo.song_key)
			this.main_mc_.text_instance:SetText("text_songnamesub",musicinfo.song_sub_key)
			this.main_mc_.text_instance:SetText("text_songnameruby",musicinfo.detail_song_key)

--			this.genre_mc_:GotoAndStop(musicinfo.genre + 1)
			this.genre_mc_:SetText("text_genre",musicinfo.genre_key)
			this.main_mc_.genre_base_instance:GotoAndStop(musicinfo.genre_key)

--			this.papamama_mc_:SetVisible(musicinfo.is_papamama)

			-- 直接ムービークリップをメンバ変数みたいに指定してアクセスできる
--			this.main_mc_.papamama_instance:SetVisible(musicinfo.is_papamama)
		end,
		DispOff = function(this)
			this.main_mc_:GotoAndStop("off");
			this.main_mc_:SetVisible(false)
		end,
		FadeOut = function(this)
			this.main_mc_:GotoAndPlay("out");
		end,
	}
end

