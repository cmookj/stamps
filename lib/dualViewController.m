classdef dualViewController < handle

  % ----------------------------------------------------------------------------
  %
  %                           P R O P E R T I E S
  %
  % ----------------------------------------------------------------------------
  properties
    windowController % figure object which contains the views
    scrollView       % scroll view
    thumbnailView    % thumbnail view

    hScrollBar    % horizontal scrollbar
    vScrollBar    % vertical scrollbar
    magBox        % magnification box (at the lower left corner of the scrollView)

    image         % image to display
    magnification % The square root of the number of pixels in scrollview to 
                  % represent 1 pixel in the image.
                  % That is, if the magnification = 2, then 2 x 2 = 4 pixels represent
                  % a single pixel of the real image.
    viewRect      % The rect of the displayed area (in the scrollview) of the real image.
                  % Hence, it is similar to the scrollview.
                  % The first two component point to the upper left corner of the image.
                  % The other two component mean the width and height of the rect, respectively.
    maxMag        % maximum magnification
    minMag        % minimum magnification
    dragViewRect  % flag to indicate the drag mode of viewRect

    scrollBarWidth
    magBoxWidth
  end


  % ----------------------------------------------------------------------------
  %
  %                              M E T H O D S
  %
  % ----------------------------------------------------------------------------
  methods
    function self = dualViewController (windowController, sView, tView)
      self.windowController = windowController;
      self.scrollView = sView;
      self.scrollView.Position = round(self.scrollView.Position);
      self.thumbnailView = tView;
      self.thumbnailView.Position = round(self.thumbnailView.Position);

      self.image = [];
      self.magnification = 1;
      self.maxMag = 16;
      self.minMag = 0.1;

      self.dragViewRect = false;
      viewRectSize = round (sView.Position(3:4)/self.magnification);
      self.viewRect = [0, 0, viewRectSize(1), viewRectSize(2)];

      self.scrollBarWidth = 13;
      self.magBoxWidth = 50;

      window = self.windowController.window;

      % Create controls

      % Magnification box
      self.magBox = uicontrol (...
        'Parent', window, ...
        'Style', 'edit', ...
        'String', '100%', ...
        'Callback', @self.magBoxCallback);

      % Horizontal scrollbar
      self.hScrollBar = uicontrol (...
        'Parent', window, ...
        'Style', 'slider', ...
        'Min', 0, 'Max', 100, 'Value', 50,...
        'Callback', @(src, event)scrollBarCallback(self, src, event));
      % addlistener (self.hScrollBar, 'Value', 'PostSet', @(src, event)scrollBarCallback(self, src, event));

      % Vertical scrollbar
      self.vScrollBar = uicontrol (...
        'Parent', window, ...
        'Style', 'slider', ...
        'Min', 0, 'Max', 100, 'Value', 50,...
        'Callback', @(src, event)scrollBarCallback(self, src, event));
      % addlistener (self.vScrollBar, 'Value', 'PostSet', @(src, event)scrollBarCallback(self, src, event));

      self.adjustLayout ();

      % ScrollWheel callback
      set (gcf, 'WindowScrollWheelFcn', @self.scrollWheelCallback);

    end


    %%
    %  adjustLayout
    %
    %  This function reduces the scroll view to accommodate vertical and horizontal
    %  scroll bars.
    %
    function adjustLayout (self)
      w = self.scrollBarWidth;
      magBoxWidth = self.magBoxWidth;
      sView = self.scrollView;

      % Magnification box
      set (self.magBox, 'Position', [sView.Position(1), sView.Position(2), magBoxWidth, w]);

      % Horizontal scrollbar
      set (self.hScrollBar, ...
        'Position', [sView.Position(1)+magBoxWidth, sView.Position(2), ...
                     sView.Position(3)-magBoxWidth-w, w]);

      % Vertical scrollbar
      set (self.vScrollBar, ...
        'Position', [sView.Position(1)+sView.Position(3)-w, sView.Position(2)+w,...
                     w, sView.Position(4)-w]);

      % Resize the scrollView
      set (self.scrollView, 'Position', [sView.Position(1), sView.Position(2)+w,...
                                         sView.Position(3)-w, sView.Position(4)-w]);

      % Main window as well as the views might have changed their sizes.
      % Re-calculate the minimum magnification.
      self.updateMinMag ();
      self.updateScrollRange ();

      % Resize the view rect in accordance to the resize of the scroll view.
      self.viewRect = [self.viewRect(1:2), round(sView.Position(3:4)/self.magnification)];

      self.windowController.app.log ('dualViewController::adjustLayout ()');
      self.windowController.app.log (sprintf ('  view rect = [%d %d %d %d]', ...
        self.viewRect(1), self.viewRect(2), self.viewRect(3), self.viewRect(4)));

      self.drawViews ();

    end


    %%
    %  scrollWheelCallback
    %
    function scrollWheelCallback (self, src, event)
      if ~isempty (self.image)
        % Get current mouse position w.r.t. figure window.
        C = get (gcf, 'CurrentPoint');
        x = C(1,1);
        y = C(1,2);

        left = self.scrollView.Position(1);
        right = self.scrollView.Position(1) + self.scrollView.Position(3);
        bottom = self.scrollView.Position(2);
        top = self.scrollView.Position(2) + self.scrollView.Position(4);

        % This callback event occurred in the scroll view.
        if (left < x) && (x < right) && (bottom < y) && (y < top)
          val = self.magnification - event.VerticalScrollCount/100;
          self.setMagnification (val);
          self.drawViews ();
        end
      end
    end


    %%
    %  setMagnification
    %
    function setMagnification (self, val)
      % Constrain the range of the magnification.
      if val > self.maxMag
        val = self.maxMag;
      elseif val < self.minMag
        val = self.minMag;
      end

      self.magnification = val;

      % Update magnification box.
      str = sprintf ('%d%%', round(val*100));
      self.magBox.String = str;

      % Update view rect and scroll ranges.
      self.updateViewRect ();
      self.updateScrollRange ();
    end


    %%
    %  drawViews
    %
    function drawViews (self)
      if ~isempty (self.image)
        self.drawThumbnailView ();
        self.drawScrollView ();
      end
    end


    %%
    %  replaceImage
    %
    function replaceImage (self, ih)
      if isequal (self.image, ih)
        return;
      end

      if self.isImageSizeDifferent (ih)
        self.image = ih;

        self.updateMinMag ();

        % Set the view rect at the center of the new image.
        newSize = round(self.scrollView.Position(3:4)/self.magnification);

        imgWidth = size (ih.CData, 2);
        imgHeight = size (ih.CData, 1);

        newCenter = round ([(imgWidth - newSize(1))/2, (imgHeight - newSize(2))/2]);

        self.viewRect = [newCenter newSize];
        self.windowController.app.log ('dualViewController::replaceImage ()');
        self.windowController.app.log (sprintf ('  view rect = [%d %d %d %d]', ...
          self.viewRect(1), self.viewRect(2), self.viewRect(3), self.viewRect(4)));

      else
        self.image = ih;

      end

      self.drawViews ();
    end


    %%
    %  drawThumbnailView
    %
    function drawThumbnailView (self)
      imshow (self.image.CData, 'Parent', self.thumbnailView, 'Border', 'tight', ...
              'InitialMagnification', 'fit');

      set (self.thumbnailView.Children, 'ButtonDownFcn', @(src, event)self.thumbnailClicked);

      self.drawViewRectOnThumbnail ();
    end


    %%
    %  drawScrollView
    %
    function drawScrollView (self)
      cropped = imcrop (self.image.CData, self.viewRect);
      imshow (cropped, 'Parent', self.scrollView, 'Border', 'tight', ...
              'InitialMagnification', self.magnification*100);
    end


    %%
    %  viewToImageCoordinate
    %
    function [u, v] = viewToImageCoordinate (self, x, y)
      u = round(x + self.viewRect(1));
      v = round(y + self.viewRect(2));
    end


    %%
    %  imageToViewCoordinate
    %
    function [x, y] = imageToViewCoordinate (self, u, v)
      x = round(u - self.viewRect(1));
      y = round(v - self.viewRect(2));
    end


    %%
    %  updateViewRect
    %
    %  This function calculates the origin and size of the view rect, trying to keep 
    %  the center of the rect.  For example, when the magnification changes, we have to
    %  re-calculate the view rect.
    %
    function updateViewRect (self)
      if self.hasImage ()
        % Zoom the view rect w.r.t. its current center.
        currentCenter = self.viewRect(1:2) + self.viewRect(3:4)/2;
        newSize = self.scrollView.Position(3:4)/self.magnification;
        newOrigin = currentCenter - newSize/2;
        newBottomRight = newOrigin + newSize;

        % Constrain the view rect not to exceed the bound of the image.
        imgWidth = size (self.image.CData, 2);
        imgHeight = size (self.image.CData, 1);

        if newOrigin(1) < 0
          newOrigin(1) = 0;
        end

        if newOrigin(2) < 0
          newOrigin(2) = 0;
        end

        if imgWidth < newBottomRight(1)
          newOrigin(1) = newOrigin(1) - newBottomRight(1) + imgWidth;
        end

        if imgHeight < newBottomRight(2)
          newOrigin(2) = newOrigin(2) - newBottomRight(2) + imgHeight;
        end

        self.viewRect = round([newOrigin newSize]);
        self.windowController.app.log (sprintf ('View rect of image scroll view = [%d %d %d %d]', ...
          self.viewRect(1), self.viewRect(2), self.viewRect(3), self.viewRect(4)));
      end
    end


    %%
    %  updateMinMag
    %
    %  This function calculates the minimum magnification considering 
    %  the size of the whole image and the dimension of the scroll view.
    %
    %  Because the scroll view and the whole image are not necessarily
    %  similar, this function calculates the vertical & horizontal minimum
    %  magnificaitons, respectively.  Then, it chooses the larger one.
    %
    function updateMinMag (self)
      if self.hasImage ()
        hRatio = self.scrollView.Position(3)/size (self.image.CData, 2);
        vRatio = self.scrollView.Position(4)/size (self.image.CData, 1);
        self.minMag = ceil(max (hRatio, vRatio)*1000)/1000;

        if self.magnification < self.minMag
          self.setMagnification (self.minMag);
        end

        self.windowController.app.log ('dualViewController::updateMinMag ()');
        self.windowController.app.log (sprintf ('  Current magnification = %f (min = %f)', ...
          self.magnification, self.minMag));
      end
    end


    %%
    %  drawViewRectOnThumbnail
    %
    function drawViewRectOnThumbnail (self)
      lineWidth = 2;
      tView = self.thumbnailView;
      rect = self.viewRect;

      left = rect(1) + lineWidth;
      right = rect(1) + rect(3);
      bottom = rect(2) + lineWidth;
      top = rect(2) + rect(4);

      x = [left, right, right, left, left];
      y = [bottom, bottom, top, top, bottom];

      if self.dragViewRect == true
        h = line (tView, x, y, 'Color', 'green', 'LineWidth', lineWidth);
      else
        h = line (tView, x, y, 'Color', 'blue', 'LineWidth', lineWidth);
      end
      set (h, 'HitTest', 'off');

    end


    %%
    %  thumbnailClicked
    %
    function thumbnailClicked (self, src, event)
      mousePosition = get (gca, 'CurrentPoint');

      x = mousePosition (1,1);
      y = mousePosition (1,2);

      left = self.viewRect(1);
      right = left + self.viewRect(3);
      top = self.viewRect(2);
      bottom = top + self.viewRect(4);

      if self.dragViewRect == false % About to move the view rect
        if (left < x) && (x < right) && (top < y) && (y < bottom) % point is in rect
          self.dragViewRect = true;
          self.drawThumbnailView ();
          set (gcf, 'WindowButtonMotionFcn', @self.mouseMoved);
        end
      else % About to finalize the move
        self.dragViewRect = false;
        set (gcf, 'WindowButtonMotionFcn', []);
        self.drawThumbnailView ();
      end
    end


    %%
    %  mouseMoved
    %
    function mouseMoved (self, src, event)
      C = get (self.thumbnailView, 'CurrentPoint');
      % title (gca, ['(X,Y) = (', num2str(C(1,1)), ', ', num2str(C(1,2)), ')']);

      w = self.viewRect(3);
      h = self.viewRect(4);
      imageW = size (self.image.CData, 2);
      imageH = size (self.image.CData, 1);

      % Regarding the current mouse position as the center of the viewRect desired,
      % calculate the origin (upper left corner) of the viewRect.
      x = round(C(1,1) - w/2);
      y = round(C(1,2) - h/2);

      if x < 0
        x = 0;
      elseif imageW - w < x
        x = round (imageW - w);
      end

      if y < 0
        y = 0;
      elseif imageH - h < y
        y = round (imageH - h);
      end

      self.viewRect(1) = x;
      self.viewRect(2) = y;

      % self.updateViewRect ();
      self.updateScrollRange ();

      self.drawViews ();
    end


    %%
    %  updateScrollRange
    %
    function updateScrollRange (self)
      if self.hasImage ()
        w = size (self.image.CData, 2);
        h = size (self.image.CData, 1);

        val = self.viewRect(1);
        if val < 0
          val = 0;
        elseif w - self.viewRect(3) < val
          val = w - self.viewRect(3);
        end

        if w <= self.viewRect(3) % Maximum <= Minimum
          set (self.hScrollBar, 'Enable', 'off');
        else
          set (self.hScrollBar, 'Enable', 'on');
          set (self.hScrollBar, 'Min', 0, 'Max', w - self.viewRect(3), 'Value', val);
        end

        val = h - self.viewRect(4) - self.viewRect(2);
        if val < 0
          val = 0;
        elseif h - self.viewRect(4) < val
          val = h - self.viewRect(4);
        end

        if h <= self.viewRect(4)
          set (self.vScrollBar, 'Enable', 'off');
        else
          set (self.vScrollBar, 'Enable', 'on');
          set (self.vScrollBar, 'Min', 0, 'Max', h - self.viewRect(4), 'Value', val);
        end
      end

    end


    %%
    %  scrollBarCallback
    %
    function scrollBarCallback (self, src, event)
      val = src.Value;
      if isequal (src, self.hScrollBar) % Horizontal scrollbar
        self.viewRect(1) = val;
      else                              % Vertical scrollbar
        self.viewRect(2) = size (self.image.CData, 1) - self.viewRect(4) - val;
      end

      % Redisplay the image
      self.drawViews ();
    end


    %%
    %  magBoxCallback
    %
    function magBoxCallback (self, src, event)
      [val, result] = str2num(src.String);
      if result % appropriate numeric input
        val = val /100; % percentage to ratio
        if val > self.maxMag
          val = self.maxMag;
        elseif val < self.minMag
          val = self.minMag;
        end
      else % inappropriate string
        val = self.magnification;
      end

      self.magnification = val;

      self.updateViewRect ();
      self.drawViews ();

      str = sprintf ('%d%%', round(val*100));
      src.String = str;
    end


    %%
    %  hasImage
    %
    function result = hasImage (self)
      if isempty (self.image)
        result = false;
      else
        result = true;
      end
    end


    %%
    %  isImageSizeDifferent
    %
    function result = isImageSizeDifferent (self, ih)
      if self.hasImage ()
        if isequal(size(self.image.CData), size(ih.CData))
          result = false;
        else
          result = true;
        end

      else % We treat a new image as a different sized image.
        result = true;
      end
    end


  end

end
