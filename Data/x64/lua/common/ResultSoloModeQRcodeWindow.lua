
ResultSoloModeQRcodeWindow = {}
function ResultSoloModeQRcodeWindow.New( instance_name )
	return
	{
		InstanceName_ = instance_name,
		WindowMc_,

		LoadMovie = function( this )
			Lumen.LoadMovie( "lumen/000_default/common/result_solomode_qrcode_window", this.InstanceName_ )
		end,

		Setup = function( this )
			if ( Lumen.IsLoadMovieFinish() == true ) then
				-- ムービークリップ取得
				this.WindowMc_ = Lumen.GetMovieClip( this.InstanceName_, true )

				if ( g_isQRCodeImageValid == true ) then
					local qr_title_mc      = this.WindowMc_:GetChildMc( "qr_title_mc", true );
					local qr_title_text_mc = qr_title_mc:GetChildMc( "qr_title_text_mc", true );
					qr_title_text_mc:SetText( "qr_title_text",     g_qrcodeWindowTitleText )
					qr_title_text_mc:SetText( "qr_title_text_sub", g_qrcodeWindowTitleTextSub )

					local guide_s_taiko_side_mc = this.WindowMc_:GetChildMc( "guide_s_taiko_side_mc", true );
					local guide_s_tx_mc         = guide_s_taiko_side_mc:GetChildMc( "guide_s_tx_mc", true );
					guide_s_tx_mc:SetText( "guide_tx", g_qrcodeWindowGuideText )
				end
			end
		end,

		LoadChildMovie = function( this )
			Lumen.LoadMovie( "lumen/000_default/common/result_solomode_qrcode_image", "dummy_qrcode_image" )
		end,

		SetupChild = function( this )
		end,


		PlayStart = function( this )
			this.WindowMc_:GotoAndPlay( "start" )
		end

	}
end

