classdef vfspDualViewController < dualViewController

properties
end


methods

  function drawScrollView (self)
    cropped = imcrop (self.image.CData, self.viewRect);

    if self.windowController.checkboxAdjustContrast.Value == 1 % Adjust contrast
      if self.windowController.checkboxManCont.Value == 1      % Manually
        M = max (cropped(:));
        m = min (cropped(:));
        k = self.windowController.sliderContrast.Value;

        % Logistic function (sigmoid)
        x0 = double(M + m)/2/255;
        x = double(cropped)./255;
        cropped = uint8(1./(1+exp(-k*(x - x0)))*255);

      else                                        % Automatically
        cropped = adapthisteq(cropped);
      end
    end

    imshow (cropped, 'Parent', self.scrollView, 'Border', 'tight', ...
            'InitialMagnification', self.magnification*100);

    self.windowController.setMouseClickCallback ();

    self.windowController.drawOverlay ();
  end

end

end
