classdef vfspAnimationWindowController < windowController

properties
  doc
  animationView

  labelChooseMarkers
  checkboxMarkersToAnimate
  buttonRedraw

  baseMargin = 5;
  buttonWidth = 150;

end


methods
  function self = vfspAnimationWindowController (doc)
    self@windowController ();
    self.doc = doc;
  end

  %%
  %  createWindow
  %
  %  This method creates a window for the animation of the markers.
  %
  function createWindow (self)
    % Create a window at full screen size
    scrsz = get(groot,'ScreenSize');
    screenWidth = scrsz(3);
    screenHeight = scrsz(4);

    self.createWindow@windowController (screenWidth, screenHeight);
    set (self.window, 'Name', 'Movement of Markers Selected');

    % Create axes and clear.
    width = self.doc.videoObject.Width;
    height = self.doc.videoObject.Height;

    self.animationView = axes ('Units', 'pixels', ...
                    'Box', 'on', ...
                    'XTick', [], 'YTick', [], ...
                    'XLim', [0 width], ...
                    'YLim', [0 height], ...
                    'xdir', 'reverse');

    cla (self.animationView);


    % Create instruction and checkboxes to choose markers to animate.
    markersCount = size (self.doc.app.markerDefaults, 1);

    % Checkboxes
    markerStrings = {markersCount, 1};
    self.checkboxMarkersToAnimate = struct;

    self.labelChooseMarkers = uicontrol (self.window, ...
        'Style', 'text', ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', ...
        'String', 'Choose markers to animate:');

    for i = 3 : markersCount-2  % Exclude coin markers, C2, and C4.
      markerKey = self.doc.app.markerDefaults{i, 7};

      markerStrings(i - 2) = strcat('<html><font color="#', ...
        self.doc.app.markerDefaults(i,3), ...
        self.doc.app.markerDefaults(i,4), ...
        self.doc.app.markerDefaults(i,5), '">', ...
        self.doc.app.markerDefaults(i,2), '</font></html>');

      checkboxHandle = uicontrol (self.window, ...
          'Style', 'checkbox', ...
          'Value', 0, ...
          'String', markerStrings{i - 2});

      self.checkboxMarkersToAnimate.(markerKey) = checkboxHandle;
    end

    % Redraw pushbutton.
    self.buttonRedraw = uicontrol (self.window, ...
                   'Style', 'pushbutton', ...
                   'String', 'Redraw', ...
                   'Callback', {@(src, event)animateMovement(self, src, event)});

    self.layoutWindow ();

    % Show the window.
    self.showWindow ();
  end


  %%
  %  animateMovement
  %
  %  This function animates trajectories of the markers selected.
  %
  function animateMovement (self, src, event)

    smoothing = self.doc.mainWindowController.ignoreSmoothed ();

    % Choose raw or smoothed trajectory to plot.
    plotData = self.doc.trajectoriesToPlot (smoothing);

    % Coordinate transformation of markers.
    self.doc.transformMarkers (plotData);

    % Make the animationView as active axes.
    cla (self.animationView);


    % Extract trajectories of the markers selected.
    markersToDraw = [];

    markersCount = size (self.doc.app.markerDefaults, 1);

    for i = 3 : markersCount-2  % Exclude coin markers, C2, and C4.
      markerKey = self.doc.app.markerDefaults{i, 7};

      if self.checkboxMarkersToAnimate.(markerKey).Value == 1 % The marker is selected.
        markersToDraw = [markersToDraw, self.doc.markersTransformed.(markerKey)];
      end

    end

    % Set the range of axis.
    min_axis = min (markersToDraw, [] ,2);
    max_axis = max (markersToDraw, [], 2);

    aspectRatioMarkerRange = (max_axis(1) - min_axis(1)) / (max_axis(2) - min_axis(2));
    aspectRatioImageView = ...
      (self.doc.mainWindowController.imageView.XLim(2) - self.doc.mainWindowController.imageView.XLim(1)) ...
        / (self.doc.mainWindowController.imageView.YLim(2) - self.doc.mainWindowController.imageView.YLim(1));

    if aspectRatioMarkerRange > aspectRatioImageView % Wider range of movement
      x_lim = [min_axis(1)-10, max_axis(1)+10];
      len = (x_lim(2) - x_lim(1)) / aspectRatioMarkerRange;
      y_lim = [min_axis(2) - .5*abs((max_axis(2) - min_axis(2))-len), ...
               max_axis(2) + .5*abs((max_axis(2) - min_axis(2))-len)];

    else % Taller range of movement
      y_lim = [min_axis(2)-5, max_axis(2)+5];
      len = (y_lim(2) - y_lim(1)) * aspectRatioMarkerRange;
      x_lim = [min_axis(1) - .5*abs((max_axis(1) - min_axis(1))-len), ...
               max_axis(1) + .5*abs((max_axis(1) - min_axis(1))-len)];

    end

    axis([x_lim, y_lim]);
    axis equal;

    for i = 1 : size(self.doc.markers.('time'), 2)
      % Mandible anterior & posterior
      key_a = self.doc.app.markerKeyMandibleAnterior;
      key_p = self.doc.app.markerKeyMandiblePosterior;
      index = 3;

      self.drawAnteriorPosterior (key_a, key_p, index, i, x_lim, y_lim);

      % Hyoid anterior & posterior
      key_a = self.doc.app.markerKeyHyoidAnterior;
      key_p = self.doc.app.markerKeyHyoidPosterior;
      index = 5;

      self.drawAnteriorPosterior (key_a, key_p, index, i, x_lim, y_lim);

      % Epiglottis
      key_a = self.doc.app.markerKeyEpiglottisTip;
      key_p = self.doc.app.markerKeyEpiglottisBase;
      index = 7;

      self.drawAnteriorPosterior (key_a, key_p, index, i, x_lim, y_lim);

      % Larynx
      key_a = self.doc.app.markerKeyVocalFoldAnterior;
      key_p = self.doc.app.markerKeyVocalFoldPosterior;
      index = 9;

      self.drawAnteriorPosterior (key_a, key_p, index, i, x_lim, y_lim);

      % Bolus (No anterior/posterior pair)
      key_a = self.doc.app.markerKeyFoodBolusHead;
      key_p = self.doc.app.markerKeyFoodBolusHead;
      index = 11;

      self.drawAnteriorPosterior (key_a, key_p, index, i, x_lim, y_lim);

      % Arytenoid (No anterior/posterior pair)
      key_a = self.doc.app.markerKeyArytenoid;
      key_p = self.doc.app.markerKeyArytenoid;
      index = 12;

      self.drawAnteriorPosterior (key_a, key_p, index, i, x_lim, y_lim);

      % Maxilla
      key_a = self.doc.app.markerKeyMaxillaAnterior;
      key_p = self.doc.app.markerKeyMaxillaPosterior;
      index = 13;

      self.drawAnteriorPosterior (key_a, key_p, index, i, x_lim, y_lim);

      % UES
      key_a = self.doc.app.markerKeyUESAnterior;
      key_p = self.doc.app.markerKeyUESPosterior;
      index = 15;

      self.drawAnteriorPosterior (key_a, key_p, index, i, x_lim, y_lim);


      pause (1./self.doc.frameRate);
    end

    grid on;
    hold off;

  end


  %%
  %  drawAnteriorPosterior
  %
  %  This function draws anterior/posterior markers and connect them.
  %  If only on is turned on, this function does not draw an edge.
  %
  function drawAnteriorPosterior (self, key_a, key_p, index, i, x_lim, y_lim)
    markerColorCode = [num2str(self.doc.app.markerDefaults {index, 3}), ' ', ...
                       num2str(self.doc.app.markerDefaults {index, 4}), ' ', ...
                       num2str(self.doc.app.markerDefaults {index, 5})];
    markerColor = (sscanf (markerColorCode, '%x').')/256;

    if self.checkboxMarkersToAnimate.(key_a).Value == 1 % Anterior is on.
      if self.checkboxMarkersToAnimate.(key_p).Value == 1 % Posterior is also on.
        plot ([self.doc.markersTransformed.(key_a)(1, i), self.doc.markersTransformed.(key_p)(1, i)], ...
              [self.doc.markersTransformed.(key_a)(2, i), self.doc.markersTransformed.(key_p)(2, i)], ...
              '--o', 'LineWidth', 1.0, ...
              'MarkerEdgeColor', 'k', ...
              'MarkerFaceColor', markerColor, ...
              'Color', markerColor, ...
              'MarkerSize', 5);
        axis ([x_lim, y_lim]);
        set (gca, 'xdir', 'reverse');
        axis equal;
        hold on;

      else % Posterior is off.
        plot (self.doc.markersTransformed.(key_a)(1, i), self.doc.markersTransformed.(key_a)(2, i), ...
              '--o', 'LineWidth', 1.0, ...
              'MarkerEdgeColor', 'k', ...
              'MarkerFaceColor', markerColor, ...
              'Color', markerColor, ...
              'MarkerSize', 5);
        axis ([x_lim, y_lim]);
        set (gca, 'xdir', 'reverse');
        axis equal;
        hold on;

      end

    else % Anterior if off.
      if self.checkboxMarkersToAnimate.(key_p).Value == 1 % Posterior is on.
        plot (self.doc.markersTransformed.(key_p)(1, i), self.doc.markersTransformed.(key_p)(2, i), ...
              '--o', 'LineWidth', 1.0, ...
              'MarkerEdgeColor', 'k', ...
              'MarkerFaceColor', markerColor, ...
              'Color', markerColor, ...
              'MarkerSize', 5);
        axis ([x_lim, y_lim]);
        set (gca, 'xdir', 'reverse');
        axis equal;
        hold on;
      end
    end

    % Mark anterior point with a label, if it is enabled.
    if self.checkboxMarkersToAnimate.(key_a).Value == 1
      if mod (i, 10) == 0 || i == 1
        label = sprintf('\\it\\bf{%d}', i);
        text (self.doc.markersTransformed.(key_a)(1, i), self.doc.markersTransformed.(key_a)(2, i), ...
              label, ...
              'verticalalignment', 'bottom', ...
              'horizontalalignment', 'left', ...
              'color', 'r', ...
              'fontsize', 12);
      end
    end

    % Mark posterior point with a label, if it is enabled.
    if ~strcmp(key_a, key_p) && self.checkboxMarkersToAnimate.(key_p).Value == 1
      if mod (i, 10) == 0 || i == 1
        label = sprintf('\\it\\bf{%d}', i);
        text (self.doc.markersTransformed.(key_p)(1, i), self.doc.markersTransformed.(key_p)(2, i), ...
              label, ...
              'verticalalignment', 'bottom', ...
              'horizontalalignment', 'left', ...
              'color', 'r', ...
              'fontsize', 12);
      end
    end

  end

end


methods (Access = protected)
  %%
  %  layoutWindow
  %
  %  This function lays views and controls in accordance to the window size.
  %
  function layoutWindow (self)
    width = self.window.Position (3);
    height = self.window.Position (4);
    controlW = self.buttonWidth;
    mgn = self.baseMargin;

    set (self.animationView, 'Position', ...
      [mgn, mgn, width-3*mgn-controlW, height-2*mgn]);

    controlH = width - mgn - controlW;
    controlV = self.animationView.Position(2) + self.animationView.Position(4) - 20;

    % Place label of the marker checkboxes.
    set (self.labelChooseMarkers, 'Position', [controlH, controlV, controlW, 20]);

    % Place checkboxes.
    markersCount = size (self.doc.app.markerDefaults, 1);
    for i = 3 : markersCount-2  % Exclude coin markers, C2, and C4.
      markerKey = self.doc.app.markerDefaults{i, 7};

      controlV = controlV - 20;
      set (self.checkboxMarkersToAnimate.(markerKey), ...
          'Position', [controlH, controlV, controlW, 12]);
    end

    % Place redraw pushbutton.
    set (self.buttonRedraw, 'Position', [controlH, self.animationView.Position(2), controlW, 24]);
  end

end

end
