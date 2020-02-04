classdef vfspDoc < handle
%
%  Properties
%
properties

  % handles
  %
  app      % main application object

  %
  % Controllers
  %
  mainWindowController
  animationWindowController  % controller for the animation of the markers transformed

  %
  % Model object (Video related members)
  %
  videoObject        % video object (result of reading of video file)
  movieFileName      % file name of the video
  moviePathName      % path to the video file
  movieData     % movie data structure
  videoFrames
  frameCount    % the number of all the frames in the movie
  frameRate     % the frame rate of the movie

  %
  % Model object (Markers related members)
  %
  hasUnsavedChanges    % flag to indicate whether there are unsaved changes
  markers              % array of the trajectories of the markers
  markersSmoothed      % array of the smoothed trajectories of the markers
  markersTransformed   % trajectories of markers coordinate-transformed using C2-C4
  smoothingParameters  % smoothing parameters

  markerCheckboxes         % Check boxes of the markers in preferences dialog
  frameIndicesWithCoinMarkers % Array of frame indices with coin markers.

  dataFile  % .mat file to save data (markers, events, smoothing parameters)

  eventFrames % Array to store the frame counter of events
end



% ----------------------------------------------------------------------------
%
%                          P U B L I C    M E T H O D S
%
% ----------------------------------------------------------------------------
methods
  % --------------------------------------------------------------------------
  %
  %  Method: vfspDoc
  %
  %  This function constructs and initializes a vfspDoc
  %  object.
  %
  % --------------------------------------------------------------------------
  function self = vfspDoc (theApp)

    self.app = theApp;

    % Get screen size
    scrsz = get(groot,'ScreenSize');
    screenWidth = scrsz(3);
    screenHeight = scrsz(4);
    self.app.log (sprintf ('Screen width: %d', scrsz(3)));
    self.app.log (sprintf ('Screen height: %d', scrsz(4)));

    % Initialize properties
    self.frameCount = 0;
    self.movieFileName = '';
    self.moviePathName = '';
    self.dataFile = '';  % No output file specified.

    % Show a file open dialog
    [filename, pathname] = uigetfile( ...
      {'*.avi; *.mpg; *.mp4; *.m4v; *.mov', ...
      'Video Files (*.avi, *.mpg, *.mp4, *.m4v, *.mov)'; ...

      '*.avi', ...
      'AVI video files (*.avi)'; ...

      '*.mpg', ...
      'MPEG-1 video files (*.mpg)'; ...

      '*.mp4; *.m4v', ...
      'MPEG-4, including H.264 encoded video files (*.mp4, *.m4v)'; ...

      '*.mov', ...
      'Apple QuickTime Movie (*.mov)'}, ...
      'Pick a video file', 'MultiSelect', 'off');
    self.movieFileName = filename;
    self.moviePathName = pathname;

    if (filename ~= 0) % A movie file is selected and opened.

      self.app.log (sprintf ('Video file opened: %s', filename));

      % Read video file into video object
      videoObject = VideoReader (strcat(pathname, filename));

      % Get information of the video file
      lastFrame = read(videoObject, inf);
      time = videoObject.CurrentTime;
      duration = videoObject.Duration;
      self.frameCount = videoObject.NumberOfFrames; % Prevent the access
                                                    % to the last frame.
      self.frameRate = round(videoObject.FrameRate);
      self.frameIndicesWithCoinMarkers = [];

      % Print log
      self.app.log (sprintf('  Video duration: %f sec', duration));
      self.app.log (sprintf('  Number of frames: %d', videoObject.NumberOfFrames));
      self.app.log (sprintf('  Frame rate: %f', self.frameRate));
      self.app.log (sprintf('  Video resolution: %d x %d', videoObject.Width, videoObject.Height));

      % After reading NumberOfFrames property from videoObject, it is not
      % possible to set current time.  Hence, re-read the video object.
      self.videoObject = VideoReader (strcat(pathname, filename));
      vidHeight = self.videoObject.Height;
      vidWidth = self.videoObject.Width;
      self.videoFrames = gobjects (self.frameCount, 1);

      % ----------------------------------------------------------------------
      %  Define struct to store marker data
      self.markers = struct;  %  Create a struct with no fields.

      % Time sequence.
      self.markers.('time') = ...
        [0:(1./self.frameRate):(self.frameCount - 1)*(1./self.frameRate)];

      self.markersSmoothed.('time') = ...
        [0:(1./self.frameRate):(self.frameCount - 1)*(1./self.frameRate)];

      % Markers (Raw data and smoothed trajectories).
      for i = 1:size(self.app.markerDefaults, 1) % Add fields according to
                                                 % the markerDefaults member
                                                 % of the app.
        self.markers.(self.app.markerDefaults{i, 7}) ...
          = zeros (2, self.frameCount); % Time series of 2 dim vector.
        self.markersSmoothed.(self.app.markerDefaults{i, 7}) ...
          = zeros (2, self.frameCount); % Time series of 2 dim vector.
      end
      % ----------------------------------------------------------------------

      % Events
      self.eventFrames = zeros (size (self.app.pref_eventStrings, 1), 1);

      % ----------------------------------------------------------------------
      %  Smoothing parameters.
      %
      %    size: number of markers by 5
      %
      %    1st column: method
      %    2nd column: parameter #1
      %    3rd column: parameter #2
      %    4th column: unused
      %    5th column: unused
      %
      %   Note that if smoothing method is -n (n: natural number),
      %   it means that re-smoothing with method n is required.
      %
      %  Method #0
      %    Name: No smoothing
      %
      %  Method #1
      %    Name: polynomial curve fitting
      %    Parameters: degree (5 .. 15)
      %
      %  Method #2
      %    Name: Moving average
      %    Parameters: span
      %
      %  Method #3
      %    Name: LOWESS
      %    Parameters: span
      %
      %  Method #4
      %    Name: LOESS
      %    Parameters: span
      %
      %  Method #5
      %    Name: Savitzky-Golay filter
      %    Parameters: span, degree
      %
      %  Method #6
      %    Name: Robust LOWESS
      %    Parameters: span
      %
      %  Method #7
      %    Name: Robust LOESS
      %    Parameters: span
      %
      for i = 1 : size(self.app.markerDefaults, 1)
        self.smoothingParameters.(self.app.markerDefaults{i, 7}) = zeros (1, 5);
      end

      % There is no unsaved change yet.
      self.hasUnsavedChanges = false;

      % Create main and animation window controller.
      self.mainWindowController = vfspWindowController (self);
      self.animationWindowController = vfspAnimationWindowController (self);

      % Create main window and set its title.
      self.mainWindowController.createWindow ();
      self.mainWindowController.setWindowTitle (filename);

      % Load the first frame and display it.
      self.mainWindowController.currentFrameIndex = 1;
      self.mainWindowController.displayFrameImageLoadingMarkersToTable ();

      % Finally, show the document window.
      self.mainWindowController.showWindow ();
      self.mainWindowController.maximizeWindow ();

    end

  end


  %%
  %  closeDocument
  %
  %  This function closes the document.
  %
  function answer = closeDocument (self, sender)

    answer = true;
    if self.hasUnsavedChanges % There are unsaved changes.
      % Bring the window to front
      self.mainWindowController.showWindow ();

      % Ask the user whether to save the changes or not.
      message = sprintf ('There are unsaved changes with %s.', ...
                         self.movieFileName);
      choice = questdlg({message, ...
                         'Do you want to save the marker data?'}, ...
        'Unsaved Changes', ...
        'No', 'Cancel', 'Yes', 'Yes');

      % Handle response
      switch choice
        case 'Yes'
          dataSaved = self.saveDataToMatFile ();
          if dataSaved == false
            answer = false;
          end

        case 'No'
          disp(''); % To prevent java.lang.NullPointerException error.

        case 'Cancel'
          answer = false;
      end

    end

    % If the answer is 'Yes' or 'No', close windows related and 
    % remove this document object from the App object.
    if answer == true
      self.animationWindowController.terminate ();
      self.mainWindowController.terminate ();

      self.app.removeDocument (self);
    end

  end


  %%
  %  trajectoriesToPlot
  %
  %  This function prepares trajectories to process.
  %
  %  If 'ignoreSmoothedTrajectories' is selected, simply copy all raw
  %  trajectories to the data to process.
  %
  %  Otherwise, this function examines every trajectory.
  %  If any of the trajectories require re-smoothing, this function opens
  %  smoothing window.
  %  If all the trajectories are either already smoothed or do not require
  %  smoothing, this function copies smoothed or raw trajectories to the data
  %  to process.
  %
  function plotData = trajectoriesToPlot (self, smoothing)

    % Choose raw or smoothed trajectory to plot.
    if smoothing == false % No smoothing required.
      % Simply copy raw trajectories.
      plotData = self.markers;

    else % Smoothing required, if necessary.

      % First, copy raw trajectories which do not require smoothing.
      for i = 1 : size (self.app.markerDefaults, 1)
        markerKey = self.app.markerDefaults {i, 7};

        if self.smoothingParameters.(markerKey)(1) == 0 % Smoothing not required.
          self.markersSmoothed.(markerKey) = self.markers.(markerKey);
        end
      end

      while self.isSmoothingRequired ()

        % Simply copy coin anterior/posterior markers without smoothing.
        % self.markersSmoothed.(self.app.markerKeyCoinAnterior) = ...
        %     self.markers.(self.app.markerKeyCoinAnterior);

        % self.markersSmoothed.(self.app.markerKeyCoinPosterior) = ...
        %     self.markers.(self.app.markerKeyCoinPosterior);

        % Open smoothing window.
        h = vfspSmthr (self.app, self);

        % Display an error message saying that re-smoothing required.
        mode = struct('WindowStyle', 'modal', 'Interpreter', 'tex');
        msgbox ({'{\bf Re-Smoothing Required}', ...
                 '     Some trajectories changed after last smoothing.'}, ...
                 'Smoothing Required Error', mode);

        % Wait the smoothing window to be closed.
        waitfor (h.window);

      end % of while

      plotData = self.markersSmoothed;

    end

  end


  %%
  %  Method: transformMarkers
  %
  %  This function transforms the trajectories of markers using C2-C4.
  %  Note that y-axis is from C4 to C2, and x-axis is obtained by
  %  rotating the y-axis by 90 degrees counter clockwise.
  %  (NOT a mathematical convention!!!)
  %
  function transformMarkers (self, plotData)
    % Examine coin markers and estimate the diameter of the coin by averaging.
    coinLengths = [];
    for i = 1 : (self.frameCount)
      coinAnterior = plotData.(self.app.markerKeyCoinAnterior)(:, i);
      coinPosterior = plotData.(self.app.markerKeyCoinPosterior)(:, i);

      if norm(coinAnterior) ~= 0 && norm(coinPosterior) ~= 0
        coinLength = norm (coinPosterior - coinAnterior);
        coinLengths = [coinLengths coinLength];
      end
    end
    coinLengthInAverage = mean (coinLengths);

    if coinLengthInAverage < 5
      mode = struct('WindowStyle', 'modal', 'Interpreter', 'tex');
      errordlg({'{\bf Coin is too small.}', ...
                '     (Shorter than 5 pixels.)'}, ...
               'Coin Picking Error', mode);
      return;
    end

    scaleFactor = self.app.pref_diameterCoin / coinLengthInAverage;

    % Create a struct to save markers transformed.
    self.markersTransformed = struct;

    % Copy time sequence.
    self.markersTransformed.('time') = self.markers.('time');

    for i = 1:size(self.app.markerDefaults, 1) % Add fields according to
                                               % the markerDefaults member
                                               % of the app.
      self.markersTransformed.(self.app.markerDefaults{i, 7}) ...
        = zeros (2, self.frameCount);  % Time series of 2 dimensional vector.
    end

    %
    % Process each frame
    % ------------------------------------------------------------------------
    for i = 1 : self.frameCount

      C2_inverted = plotData.(self.app.markerKeyC2)(:, i);
      C4_inverted = plotData.(self.app.markerKeyC4)(:, i);

      % Invert vertical axis (v).
      imageHeight = self.videoObject.Height;

      C2 = C2_inverted;
      C2(2) = imageHeight - C2_inverted(2);

      C4 = C4_inverted;
      C4(2) = imageHeight - C4_inverted(2);

      R = eye(2);
      p = zeros(2, 1);

      if norm(C2) ~= 0 && norm(C4) ~= 0
        % Setup x-y coordinate system.
        % The head and tail of y-axis are C2 and C4 markers, respectively.
        % The x-axis is obtained by rotating the y-axis by 90 degrees clockwise.

        if norm(C2 - C4) < 5
          mode = struct('WindowStyle', 'modal', 'Interpreter', 'tex');
          description = ...
            sprintf('     (Less than 5 pixels apart at frame %d.)', i);
          errordlg({'{\bf Markers for C2 and C4 are too close.}', ...
                    description}, ...
                   'Markers Too Close Error', mode);
          return;
        end

        y_hat = (C2 - C4)/norm(C2 - C4);
        angle = -pi/2;
        x_hat = [cos(angle) -sin(angle); sin(angle) cos(angle)]*y_hat;
        R = [x_hat y_hat];
        p = C4;
      end % of if

      % Convert (u, v) to (x, y).

      for j = 1 : size(self.app.markerDefaults, 1)

        % Extract uv coordinate of each marker.
        markerKey = self.app.markerDefaults{j, 7};
        marker = plotData.(markerKey)(:, i);

        % Invert v coordinate so that the lower left corner should be (0, 0).
        markerInverted = marker;
        markerInverted(2) = imageHeight - marker(2);

        % Transform the coordinate, and
        % negate the x-coordinates because left-handed coordinate system
        % is used for x-y coordinate system.
        self.markersTransformed.(markerKey)(:, i) = ...
          scaleFactor * [-1 0; 0 1] * (R' * markerInverted - R'*p);

      end % of for j

    end % of for i

  end


  %%
  %  smoothTrajectories
  %
  %  This function filters and smooths the trajectories of markers.
  %
  function smoothTrajectories (self)

    % Simply copy coin anterior/posterior markers without smoothing.
    self.markersSmoothed.(self.app.markerKeyCoinAnterior) = ...
        self.markers.(self.app.markerKeyCoinAnterior);

    self.markersSmoothed.(self.app.markerKeyCoinPosterior) = ...
        self.markers.(self.app.markerKeyCoinPosterior);

    vfspSmthr (self.app, self);
  end


  %%
  %  plotTrajectories
  %
  %  This function plots trajectories of the markers.
  %
  function plotTrajectories (self, smoothing)

    % Choose raw or smoothed trajectory to plot.
    plotData = self.trajectoriesToPlot (smoothing);

    % Coordinate transformation of markers.
    self.transformMarkers (plotData);

    % ------------------------------------------------------------------------

    tseq = plotData.('time');

    % Create a window for displacement plots.
    scsize = get(0, 'screensize');
    mainWindowPosition = [0.1*scsize(3) 0.07*scsize(4) 0.8*scsize(3) 0.8*scsize(4)];
    mainWindowName = sprintf('Displacements of %s', self.movieFileName);

    mainPlotWindow = figure ( ...
      'NumberTitle', 'off', ...
      'Position', mainWindowPosition, ...
      'Name', mainWindowName ...
      );

    % Hyoid vertical movement
    subplot (3, 3, 1);
    key = self.app.markerKeyHyoidAnterior;
    plot (tseq, self.markersTransformed.(key)(2, :), 'b', 'linewidth', 1.5);
    grid on;
    ylabel ('displacement[mm]', 'fontsize', 10);
    xlabel ('time[sec]', 'fontsize', 10);
    title ('\bf{Hyoid: vertical movement}');

    % Hyoid horizontal movement
    key = self.app.markerKeyHyoidAnterior;
    subplot (3, 3, 4); % Just below the subplot above.
    plot (tseq, self.markersTransformed.(key)(1, :), 'b', 'linewidth', 1.5);
    grid on;
    ylabel ('displacement[mm]', 'fontsize', 10);
    xlabel ('time[sec]', 'fontsize', 10);
    title ('\bf{Hyoid: horizontal movement}');

    % Larynx vertical movement
    subplot (3, 3, 2);
    key = self.app.markerKeyVocalFoldAnterior;
    plot (tseq, self.markersTransformed.(key)(2, :), 'k', 'linewidth', 1.5);
    grid on;
    ylabel ('displacement[mm]', 'fontsize', 10);
    xlabel ('time[sec]', 'fontsize', 10);
    title ('\bf{Larynx: vertical movement}');

    % Larynx horizontal movement
    subplot (3, 3, 5);
    key = self.app.markerKeyVocalFoldAnterior;
    plot (tseq, self.markersTransformed.(key)(1, :), 'k', 'linewidth', 1.5);
    grid on;
    ylabel ('displacement[mm]', 'fontsize', 10);
    xlabel ('time[sec]', 'fontsize', 10);
    title ('\bf{Larynx: horizontal movement}');

    % Arytenoid vertical movement
    subplot (3, 3, 3);
    key = self.app.markerKeyArytenoid;
    plot (tseq, self.markersTransformed.(key)(2, :), 'k', 'linewidth', 1.5);
    grid on;
    ylabel ('displacement[mm]', 'fontsize', 10);
    xlabel ('time[sec]', 'fontsize', 10);
    title ('\bf{Arytenoid: vertical movement}');

    % Arytenoid horizontal movement
    subplot (3, 3, 6);
    key = self.app.markerKeyArytenoid;
    plot (tseq, self.markersTransformed.(key)(1, :), 'k', 'linewidth', 1.5);
    grid on;
    ylabel ('displacement[mm]', 'fontsize', 10);
    xlabel ('time[sec]', 'fontsize', 10);
    title ('\bf{Arytenoid: horizontal movement}');

    % Epiglottic angle
    horizontalMirror = [-1 0; 0 1];
    key_b = self.app.markerKeyEpiglottisBase;
    key_t = self.app.markerKeyEpiglottisTip;
    delta = horizontalMirror * (self.markersTransformed.(key_t) ...
                                - self.markersTransformed.(key_b));
    epiglotticAngle = atan2 (delta(2, :), delta(1, :));

    % Clockwise rotation is positive for Epiglottis angle (NOT mathematical).
    epglts_angle_from_initial = -(epiglotticAngle - epiglotticAngle(1));
    epglts_angle_from_initial_deg = epglts_angle_from_initial * 180/pi;

    subplot (3, 3, 7);
    plot (tseq, epglts_angle_from_initial_deg, 'r', 'linewidth', 1.5);
    grid on;
    ylabel ('angle[deg]', 'fontsize', 10);
    xlabel ('time[sec]', 'fontsize', 10);
    title ('\bf{Epiglottic angle}');

    % Head of fluid
    subplot (3, 3, 8);
    key = self.app.markerKeyFoodBolusHead;
    plot (tseq, self.markersTransformed.(key)(2, :), 'm', 'linewidth', 1.5);
    grid on;
    ylabel ('displacement[mm]', 'fontsize', 10);
    xlabel ('time[sec]', 'fontsize', 10);
    title ('\bf{Head of Bolus}');

    % UES opening
    subplot (3, 3, 9);
    key1 = self.app.markerKeyUESAnterior;
    key2 = self.app.markerKeyUESPosterior;
    difference = self.markersTransformed.(key1) - self.markersTransformed.(key2);
    distance = sqrt (difference(1,:).^2 + difference(2,:).^2);
    plot (tseq, distance, 'linewidth', 1.5);
    grid on;
    ylabel ('displacement[mm]', 'fontsize', 10);
    xlabel ('time[sec]', 'fontsize', 10);
    title ('\bf{UES opening}');


    % % Hyoid excursion
    % subplot (3, 3, 1);
    % key = self.app.markerKeyHyoidAnterior;
    % plot (self.markersTransformed.(key)(1, :), ...
    %       self.markersTransformed.(key)(2, :), ...
    %       ':ob', ...
    %       'LineWidth', 1.0, ...
    %       'MarkerEdgeColor', 'k', ...
    %       'MarkerFaceColor', 'y', ...
    %       'MarkerSize', 5);
    % grid on;

    % indexToLabel = [0:5:self.frameCount];
    % indexToLabel(1) = 1;
    % for i = 1 : size(indexToLabel, 2)
    %   label = sprintf('\\it\\bf{%d}', indexToLabel(i));
    %   text (self.markersTransformed.(key)(1, indexToLabel(i)), ...
    %         self.markersTransformed.(key)(2, indexToLabel(i)), ...
    %         label, ...
    %         'verticalalignment', 'bottom', ...
    %         'horizontalalignment', 'left', ...
    %         'color', 'r', ...
    %         'fontsize', 12);
    % end

    % ylabel ('distance[mm]', 'fontsize', 10);
    % xlabel ('distance[mm]', 'fontsize', 10);
    % title ('\bf{Hyoid excursion}');

    % % Larynx posterior
    % subplot (3, 3, 8);
    % key = self.app.markerKeyVocalFoldPosterior;
    % plot (tseq, self.markersTransformed.(key)(2, :), 'k', 'linewidth', 1.5);
    % grid on;
    % ylabel ('distance[mm]', 'fontsize', 10);
    % xlabel ('time[sec]', 'fontsize', 10);
    % title ('\bf{Larynx-post. edge}');

    % % Epiglottis-Hyoid anterior
    % subplot (3, 3, 9);
    % key = self.app.markerKeyHyoidAnterior;
    % plot (self.markersTransformed.(key)(1, :), ...
    %       epiglotticAngleDeg, ...
    %       ':ok', 'LineWidth', 1.0, ...
    %       'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'c', ...
    %       'MarkerSize', 5);
    % grid on;
    % ylabel ('epiglottic angle', 'fontsize', 10);
    % xlabel ('hyoid horizontal', 'fontsize', 10);
    % title ('\bf{Epiglottis-Hyoid(ant.)}');


    % Create another window for velocity plots.
    subWindowPosition = mainWindowPosition + [10 -10 0 0];
    subWindowName = sprintf('Velocities of %s', self.movieFileName);

    subPlotWindow = figure ( ...
      'NumberTitle', 'off', ...
      'Position', subWindowPosition, ...
      'Name', subWindowName ...
      );

    dt = 1./self.frameRate;

    % Hyoid vertical movement
    subplot (3, 3, 1);
    key = self.app.markerKeyHyoidAnterior;
    plot (tseq, ...
          self.approximateVelocity (self.markersTransformed.(key)(2, :), dt), ...
          'b', 'linewidth', 1.5);
    grid on;
    ylabel ('velocity[mm/s]', 'fontsize', 10);
    xlabel ('time[sec]', 'fontsize', 10);
    title ('\bf{Hyoid: vertical velocity}');

    % Hyoid horizontal movement
    key = self.app.markerKeyHyoidAnterior;
    subplot (3, 3, 4); % Just below the subplot above.
    plot (tseq, ...
          self.approximateVelocity (self.markersTransformed.(key)(1, :), dt), ...
          'b', 'linewidth', 1.5);
    grid on;
    ylabel ('velocity[mm/s]', 'fontsize', 10);
    xlabel ('time[sec]', 'fontsize', 10);
    title ('\bf{Hyoid: horizontal velocity}');

    % Larynx vertical movement
    subplot (3, 3, 2);
    key = self.app.markerKeyVocalFoldAnterior;
    plot (tseq, ...
          self.approximateVelocity (self.markersTransformed.(key)(2, :), dt), ...
          'k', 'linewidth', 1.5);
    grid on;
    ylabel ('velocity[mm/s]', 'fontsize', 10);
    xlabel ('time[sec]', 'fontsize', 10);
    title ('\bf{Larynx: vertical velocity}');

    % Larynx horizontal movement
    subplot (3, 3, 5);
    key = self.app.markerKeyVocalFoldAnterior;
    plot (tseq, ...
          self.approximateVelocity (self.markersTransformed.(key)(1, :), dt), ...
          'k', 'linewidth', 1.5);
    grid on;
    ylabel ('velocity[mm/s]', 'fontsize', 10);
    xlabel ('time[sec]', 'fontsize', 10);
    title ('\bf{Larynx: horizontal velocity}');

    % Arytenoid vertical movement
    subplot (3, 3, 3);
    key = self.app.markerKeyArytenoid;
    plot (tseq, ...
          self.approximateVelocity (self.markersTransformed.(key)(2, :), dt), ...
          'k', 'linewidth', 1.5);
    grid on;
    ylabel ('velocity[mm/s]', 'fontsize', 10);
    xlabel ('time[sec]', 'fontsize', 10);
    title ('\bf{Arytenoid: vertical velocity}');

    % Arytenoid horizontal movement
    subplot (3, 3, 6);
    key = self.app.markerKeyArytenoid;
    plot (tseq, ...
          self.approximateVelocity (self.markersTransformed.(key)(1, :), dt), ...
          'k', 'linewidth', 1.5);
    grid on;
    ylabel ('velocity[mm/s]', 'fontsize', 10);
    xlabel ('time[sec]', 'fontsize', 10);
    title ('\bf{Arytenoid: horizontal velocity}');

    % Epiglottic angle
    subplot (3, 3, 7);
    plot (tseq, ...
          self.approximateVelocity (epglts_angle_from_initial_deg, dt), ...
          'r', 'linewidth', 1.5);
    grid on;
    ylabel ('angular velocity[deg/s]', 'fontsize', 10);
    xlabel ('time[sec]', 'fontsize', 10);
    title ('\bf{Epiglottic angular velocity}');

    % Head of Bolus
    subplot (3, 3, 8);
    key = self.app.markerKeyFoodBolusHead;
    bolusHorizontalVelocity = ...
      self.approximateVelocity (self.markersTransformed.(key)(1, :), dt);
    bolusVerticalVelocity = ...
      self.approximateVelocity (self.markersTransformed.(key)(2, :), dt);
    bolusVelocity = sqrt (bolusHorizontalVelocity.^2 + ...
                          bolusVerticalVelocity.^2);
    plot (tseq, bolusVelocity, ...
          'm', 'linewidth', 1.5);
    grid on;
    ylabel ('velocity[mm/s]', 'fontsize', 10);
    xlabel ('time[sec]', 'fontsize', 10);
    title ('\bf{Head of Bolus}');

    % UES opening
    subplot (3, 3, 9);
    plot (tseq, ...
          self.approximateVelocity (distance, dt), ...
          'linewidth', 1.5);
    grid on;
    ylabel ('velocity[mm/s]', 'fontsize', 10);
    xlabel ('time[sec]', 'fontsize', 10);
    title ('\bf{UES opening velocity}');

  end


  %%
  %  plotSuperimposing
  %
  %  This callback function creates superimposing plot.
  %
  function plotSuperimposing (self, smoothing)

    % Choose raw or smoothed trajectory to plot.
    plotData = self.trajectoriesToPlot (smoothing);

    % Coordinate transformation of markers.
    self.transformMarkers (plotData);

    % Create a window.
    scsize = get(0, 'screensize');
    plotPosition = [0.2*scsize(4) 0.07*scsize(4) 0.8*scsize(4) 0.8*scsize(4)];
    superimposingPlotWindow = figure ( ...
      'NumberTitle', 'off', ...
      'Position', plotPosition.*[0.8 7 1.0 0.8], ...
      'Name', 'Superimposing' ...
      );

    tseq = plotData.('time');

    % Hyoid-vertical displacement
    key = self.app.markerKeyHyoidAnterior;
    l1 = line (tseq, self.markersTransformed.(key)(2, :));
    hold on;
    set (l1, 'color', 'b', 'linewidth', 1.5);

    % Food bolus head
    key = self.app.markerKeyFoodBolusHead;
    l2 = line (tseq, self.markersTransformed.(key)(2, :));
    hold on;
    set (l2, 'color', 'm', 'linestyle', '--', 'linewidth', 1.5);

    % Vocal fold anterior vertical displacement
    key = self.app.markerKeyVocalFoldAnterior;
    l3 = line (tseq, self.markersTransformed.(key)(2, :));
    hold on;
    set (l3, 'color', 'k', 'linestyle', '-.', 'linewidth', 1.5);

    % Epiglottic angle
    horizontalMirror = [-1 0; 0 1];
    key_b = self.app.markerKeyEpiglottisBase;
    key_t = self.app.markerKeyEpiglottisTip;
    delta = horizontalMirror * (self.markersTransformed.(key_t) ...
                                - self.markersTransformed.(key_b));
    epiglotticAngle = atan2 (delta(2, :), delta(1, :));
    epiglotticAngle = -(epiglotticAngle - epiglotticAngle(1)); % Clockwise
                                                               % rotation is
                                                               % positive.
    epiglotticAngleDeg = epiglotticAngle * 180 / pi;

    l4 = line (tseq, epiglotticAngleDeg);
    hold on;
    set (l4, 'color', 'r', 'linewidth', 2, 'lineStyle', '-');

    % Arytenoid
    key = self.app.markerKeyArytenoid;
    l5 = line (tseq, self.markersTransformed.(key)(2, :));
    hold off;
    set (l5, 'color', 'k', 'linewidth', 2, 'lineStyle', ':');

    legend ([l1, l2, l3, l4, l5], ...
            'hyoid (mm)', ...
            'fluid (mm)', ...
            'larynx (mm)', ...
            'epiglottic angle (deg)', ...
            'arytenoid (mm)');

    xlabel ('\bf{time[sec]}', 'fontsize', 11);
    ylabel ('\bf{vertical displacement[mm]}', 'fontsize', 11);
    title ('\bf{Superimposing}', 'fontsize', 11);
    ylim ('auto');
    xlim ('auto');

    grid on;

  end


  %%
  %  isSmoothingRequired
  %
  %  This function examines all the trajectories whether smoothing is
  %  required or not.
  %
  function answer = isSmoothingRequired (self)
    answer = false;

    % Examine whether re-smoothing is required or not, e.g.,
    % the raw trajectories changed without re-smoothing.
    for i = 3 : size (self.app.markerDefaults, 1)
      if self.smoothingParameters.(self.app.markerDefaults{i, 7})(1) < 0
        answer = true;

        % No need to examine further.
        break;
      end
    end
  end


  %%
  %  saveDataToMatFile
  %
  %  This function saves current markers, events, and smoothing
  %  scheme to a .mat file.
  %
  function result = saveDataToMatFile (self)

    result = true;

    if size(self.dataFile, 1) == 0 % No file specified yet.
      [file, path] = uiputfile ('*.mat', 'Save Marker Data As');

      if file == 0 % User didn't choose a file to save.
        result = false;
        return;
      end

      self.dataFile = strcat (path, file);
      set (self.buttons(self.saveButtonIndex), 'String', 'Save Data');
    end

    vfspVersion = self.app.version();
    markers = self.markers;
    smoothingParameters = self.smoothingParameters;
    markersSmoothed = self.markersSmoothed;

    save (self.dataFile, ...
          'vfspVersion', ...
          'markers', ...
          'smoothingParameters', ...
          'markersSmoothed');

    % Mark there is unsaved change.
    self.hasUnsavedChanges = false;

    % Change the window title.
    self.mainWindowController.setWindowTitle (self.movieFileName);
  end


  %%
  %  loadDataFromMatFile
  %
  %  This function loads markers, events, and smoothing scheme
  %  from a .mat file.
  %
  function result = loadDataFromMatFile (self)
    result = true;
    [file, path] = uigetfile ('*.mat', 'Load Marker Data From');

    if file == 0
      result = false;
      return;
    end

    self.dataFile = strcat (path, file);
    load (self.dataFile, 'markers', 'vfspVersion');

    % Examine the version and data of mat file.
    if vfspVersion >= 0.51
      countFrames = size (markers.time, 2);

      if countFrames < self.frameCount % Saved sequence is shorter
        choice = questdlg({'Saved sequence is shorter than the video.', ...
                           'Would you like to load the data?', ...
                           '(The data will be loaded as far as possible.)'}, ...
                           'Shorter Sequence', 'Yes', 'No', 'Yes');

        switch choice
          case 'Yes'
            copyMarkerDataUpto (self, countFrames, markers);

          case 'No'
            return;
        end

      elseif countFrames == self.frameCount % Same lengths
        self.markers = markers;

      elseif self.frameCount < countFrames % Saved sequence is longer
        choice = questdlg({'Saved sequence is longer than the video.', ...
                           'Would you like to load the data?', ...
                           '(The data will be truncated.)'}, ...
                           'Longer Sequence', 'Yes', 'No', 'Yes');

        switch choice
          case 'Yes'
            copyMarkerDataUpto (self, self.frameCount, markers);

          case 'No'
            return;
        end
      end

    end % of if vfspVersion >= 0.51

    % if vfspVersion >= 0.6 && vfspVersion < 0.9
    %   load (self.dataFile, 'smoothnessParameters');
    %   self.smoothingParameters = smoothnessParameters;
    % end % of if vfspVersion >= 0.6

    if vfspVersion >= 0.9
      load (self.dataFile, ...
            'smoothingParameters', ...
            'markersSmoothed');
      self.smoothingParameters = smoothingParameters;
      self.markersSmoothed = markersSmoothed;
    end

  end


  %%
  %  exportToFile
  %
  %  This function exports data to a text file.
  %
  function exportToFile(self, smoothing)

    % Ask user to choose a file to export data.
    filter = {...
      '*.xlsx', 'Microsoft Excel worksheet (*.xlsx)'; ...
      '*.txt', 'Text file (*.txt)'};
    [file, path, indx] = uiputfile (filter, 'Export Marker Data As');

    if file == 0 % User didn't choose a file to save.
      return;
    end

    exportFile = strcat (path, file);

    % Choose raw or smoothed trajectory to plot.
    plotData = self.trajectoriesToPlot (smoothing);

    % Coordinate transformation of markers.
    self.transformMarkers (plotData);

    % Time difference.
    dt = 1./self.frameRate;

    % Hyoid bone
    key = self.app.markerKeyHyoidAnterior;
    [v_disp_hyoid, h_disp_hyoid, max_disp_hyoid] = ...
        self.maximalDisplacementOfMarker (self.markersTransformed.(key));
    [v_vel_hyoid, h_vel_hyoid, max_vel_hyoid] = ...
        self.maximalVelocityOfMarker (self.markersTransformed.(key), dt);


    % Larynx
    key = self.app.markerKeyVocalFoldAnterior;
    [v_disp_larynx, h_disp_larynx, max_disp_larynx] = ...
        self.maximalDisplacementOfMarker (self.markersTransformed.(key));
    [v_vel_larynx, h_vel_larynx, max_vel_larynx] = ...
        self.maximalVelocityOfMarker (self.markersTransformed.(key), dt);


    % Arytenoid
    key = self.app.markerKeyArytenoid;
    [v_disp_arytenoid, h_disp_arytenoid, max_disp_arytenoid] = ...
        self.maximalDisplacementOfMarker (self.markersTransformed.(key));
    [v_vel_arytenoid, h_vel_arytenoid, max_vel_arytenoid] = ...
        self.maximalVelocityOfMarker (self.markersTransformed.(key), dt);


    % UES
    key1 = self.app.markerKeyUESAnterior;
    key2 = self.app.markerKeyUESPosterior;
    [max_ues, mean_ues] = self.distanceBetweenMarkers (self.markersTransformed.(key1), ...
                                               self.markersTransformed.(key2));


    % C2-C4 distance
    key1 = self.app.markerKeyC2;
    key2 = self.app.markerKeyC4;
    [max_c2c4, mean_c2c4] = self.distanceBetweenMarkers (self.markersTransformed.(key1), ...
                                                 self.markersTransformed.(key2));


    % Epiglottis
    horizontalMirror = [-1 0; 0 1];
    key_b = self.app.markerKeyEpiglottisBase;
    key_t = self.app.markerKeyEpiglottisTip;
    delta = horizontalMirror * (self.markersTransformed.(key_t) ...
                                - self.markersTransformed.(key_b));
    epiglotticAngle = atan2 (delta(2, :), delta(1, :));

    % Clockwise rotation is positive for Epiglottis angle (NOT mathematical).
    epglts_angle_from_initial = -(epiglotticAngle - epiglotticAngle(1));
    epglts_angle_from_y = -(epiglotticAngle - pi/2);

    max_epglts_angle_from_initial = max (epglts_angle_from_initial) * 180/pi;
    max_epglts_angle_from_y = max (epglts_angle_from_y) * 180/pi;

    max_vel_epglts = max (self.approximateVelocity (epglts_angle_from_initial, dt));
    max_vel_epglts = max_vel_epglts * 180/pi;

    % Bolus
    key = self.app.markerKeyFoodBolusHead;
    [v_vel_bolus, h_vel_bolus, max_vel_bolus] = ...
        self.maximalVelocityOfMarker (-self.markersTransformed.(key), dt);

    % Build a table of maximal values.
    M = table (...
      v_disp_hyoid, h_disp_hyoid, max_disp_hyoid, ...
      v_disp_larynx, h_disp_larynx, max_disp_larynx, ...
      v_disp_arytenoid, h_disp_arytenoid, max_disp_arytenoid, ...
      max_ues, mean_ues, ...
      max_c2c4, mean_c2c4, ...
      max_epglts_angle_from_initial, max_epglts_angle_from_y, ...
      v_vel_hyoid, h_vel_hyoid, max_vel_hyoid, ...
      v_vel_larynx, h_vel_larynx, max_vel_larynx, ...
      v_vel_arytenoid, h_vel_arytenoid, max_vel_arytenoid, ...
      max_vel_epglts, max_vel_bolus ...
      );

    % Build a table of all the markers transformed.
    frame = [1:size(self.markersTransformed.('time'), 2)]';

    key = self.app.markerKeyCoinAnterior;
    coin_ant_x = self.markersTransformed.(key)(1,:)';
    coin_ant_y = self.markersTransformed.(key)(2,:)';

    key = self.app.markerKeyCoinPosterior;
    coin_post_x = self.markersTransformed.(key)(1,:)';
    coin_post_y = self.markersTransformed.(key)(2,:)';

    key = self.app.markerKeyMandibleAnterior;
    mandible_ant_x = self.markersTransformed.(key)(1,:)';
    mandible_ant_y = self.markersTransformed.(key)(2,:)';

    key = self.app.markerKeyMandiblePosterior;
    mandible_post_x = self.markersTransformed.(key)(1,:)';
    mandible_post_y = self.markersTransformed.(key)(2,:)';

    key = self.app.markerKeyHyoidAnterior;
    hyoid_ant_x = self.markersTransformed.(key)(1,:)';
    hyoid_ant_y = self.markersTransformed.(key)(2,:)';

    key = self.app.markerKeyHyoidPosterior;
    hyoid_post_x = self.markersTransformed.(key)(1,:)';
    hyoid_post_y = self.markersTransformed.(key)(2,:)';

    key = self.app.markerKeyEpiglottisTip;
    epiglottis_tip_x = self.markersTransformed.(key)(1,:)';
    epiglottis_tip_y = self.markersTransformed.(key)(2,:)';

    key = self.app.markerKeyEpiglottisBase;
    epiglottis_base_x = self.markersTransformed.(key)(1,:)';
    epiglottis_base_y = self.markersTransformed.(key)(2,:)';

    key = self.app.markerKeyVocalFoldAnterior;
    larynx_ant_x = self.markersTransformed.(key)(1,:)';
    larynx_ant_y = self.markersTransformed.(key)(2,:)';

    key = self.app.markerKeyVocalFoldPosterior;
    larynx_post_x = self.markersTransformed.(key)(1,:)';
    larynx_post_y = self.markersTransformed.(key)(2,:)';

    key = self.app.markerKeyFoodBolusHead;
    bolus_x = self.markersTransformed.(key)(1,:)';
    bolus_y = self.markersTransformed.(key)(2,:)';

    key = self.app.markerKeyArytenoid;
    arytenoid_x = self.markersTransformed.(key)(1,:)';
    arytenoid_y = self.markersTransformed.(key)(2,:)';

    key = self.app.markerKeyMaxillaAnterior;
    maxilla_ant_x = self.markersTransformed.(key)(1,:)';
    maxilla_ant_y = self.markersTransformed.(key)(2,:)';

    key = self.app.markerKeyMaxillaPosterior;
    maxilla_post_x = self.markersTransformed.(key)(1,:)';
    maxilla_post_y = self.markersTransformed.(key)(2,:)';

    key = self.app.markerKeyUESAnterior;
    ues_ant_x = self.markersTransformed.(key)(1,:)';
    ues_ant_y = self.markersTransformed.(key)(2,:)';

    key = self.app.markerKeyUESPosterior;
    ues_post_x = self.markersTransformed.(key)(1,:)';
    ues_post_y = self.markersTransformed.(key)(2,:)';

    key = self.app.markerKeyC2;
    c2_x = self.markersTransformed.(key)(1,:)';
    c2_y = self.markersTransformed.(key)(2,:)';

    key = self.app.markerKeyC4;
    c4_x = self.markersTransformed.(key)(1,:)';
    c4_y = self.markersTransformed.(key)(2,:)';

    T = table (frame, ...
      coin_ant_x, coin_ant_y, ...
      coin_post_x, coin_post_y, ...
      mandible_ant_x, mandible_ant_y, ...
      mandible_post_x, mandible_post_y, ...
      hyoid_ant_x, hyoid_ant_y, ...
      hyoid_post_x, hyoid_post_y, ...
      epiglottis_tip_x, epiglottis_tip_y, ...
      epiglottis_base_x, epiglottis_base_y, ...
      larynx_ant_x, larynx_ant_y, ...
      larynx_post_x, larynx_post_y, ...
      bolus_x, bolus_y, ...
      arytenoid_x, arytenoid_y, ...
      maxilla_ant_x, maxilla_ant_y, ...
      maxilla_post_x, maxilla_post_y, ...
      ues_ant_x, ues_ant_y, ...
      ues_post_x, ues_post_y, ...
      c2_x, c2_y, ...
      c4_x, c4_y ...
      );

    % Find markers whose positions NOT specified, and replace the coordinates
    % with NaN.

    for i = 1 : self.frameCount % For each row of the table, T
      for j = 1 : size(self.app.markerDefaults, 1) % For each marker

        % If the marker is disabled, change the table cell to 'NaN'.
        markerEnabled = self.app.markerDefaults{j, 1};

        if markerEnabled == 0
          T (i, 2*j:2*j+1) = {NaN, NaN};

        else
          markerKey = self.app.markerDefaults{j, 7};
          marker = plotData.(markerKey)(:, i);

          if marker(1) == 0 || marker(2) == 0
            T (i, 2*j:2*j+1) = {NaN, NaN};
          end

        end

      end % of for j
    end


    switch indx
    case 1 % Excel file
      writetable (T, exportFile, 'Sheet', 1);
      writetable (M, exportFile, 'Sheet', 2);

    case 2 % TEXT file
      writetable (M, exportFile);

    end


    % Export data to file.
    % FID = fopen (exportFile, 'w');

    % fprintf (FID, '__DISTANCE_[mm]__\n\n');

    % fprintf (FID, '_HYOID_BONE_\n');
    % fprintf (FID, 'Vertical_displacement: %f\n', vd_hyoid);
    % fprintf (FID, 'Horizontal_displacement: %f\n', hd_hyoid);
    % fprintf (FID, '2D_maximal_displacement: %f\n\n', md_hyoid);

    % fprintf (FID, '_LARYNX_\n');
    % fprintf (FID, 'Vertical_displacement: %f\n', vd_larynx);
    % fprintf (FID, 'Horizontal_displacement: %f\n', hd_larynx);
    % fprintf (FID, '2D_maximal_displacement: %f\n\n', md_larynx);

    % fprintf (FID, '_ARYTENOID_\n');
    % fprintf (FID, 'Vertical_displacement: %f\n', vd_arytenoid);
    % fprintf (FID, 'Horizontal_displacement: %f\n', hd_arytenoid);
    % fprintf (FID, '2D_maximal_displacement: %f\n\n', md_arytenoid);

    % fprintf (FID, '_UES_\n');
    % fprintf (FID, 'Maximal_UES_opening: %f\n\n', max_ues);

    % fprintf (FID, '_C2-C4_\n');
    % fprintf (FID, 'Mean_C2-C4: %f\n\n', mean_c2c4);

    % fprintf (FID, '_EPIGLOTTIS_\n');
    % fprintf (FID, 'Maximal_tilt_angle_from_initial_position: %f\n', ...
             % max_epglts_angle_from_initial);
    % fprintf (FID, 'Maximal_tilt_angle_from_y_axis: %f\n\n', ...
             % max_epglts_angle_from_y);

    % fprintf (FID, '\n__VELOCITY_[mm/sec, deg/sec]__\n\n');

    % fprintf (FID, '_HYOID_BONE_\n');
    % fprintf (FID, 'Vertical_velocity: %f\n', vv_hyoid);
    % fprintf (FID, 'Horizontal_velocity: %f\n', hv_hyoid);
    % fprintf (FID, '2D_maximal_velocity: %f\n\n', mv_hyoid);

    % fprintf (FID, '_LARYNX_\n');
    % fprintf (FID, 'Vertical_velocity: %f\n', vv_larynx);
    % fprintf (FID, 'Horizontal_velocity: %f\n', hv_larynx);
    % fprintf (FID, '2D_maximal_velocity: %f\n\n', mv_larynx);

    % fprintf (FID, '_ARYTENOID_\n');
    % fprintf (FID, 'Vertical_velocity: %f\n', vv_arytenoid);
    % fprintf (FID, 'Horizontal_velocity: %f\n', hv_arytenoid);
    % fprintf (FID, '2D_maximal_velocity: %f\n\n', mv_arytenoid);

    % fprintf (FID, '_EPIGLOTTIS_\n');
    % fprintf (FID, 'Maximal_angular_velocity: %f\n\n', v_max_epglts);

    % fprintf (FID, '_BOLUS_\n');
    % fprintf (FID, 'Maximal_velocity: %f\n\n', mv_bolus);

    % Displacements
    % fprintf (FID, '%f    ', vd_hyoid);
    % fprintf (FID, '%f    ', hd_hyoid);
    % fprintf (FID, '%f    ', md_hyoid);

    % fprintf (FID, '%f    ', vd_larynx);
    % fprintf (FID, '%f    ', hd_larynx);
    % fprintf (FID, '%f    ', md_larynx);

    % fprintf (FID, '%f    ', vd_arytenoid);
    % fprintf (FID, '%f    ', hd_arytenoid);
    % fprintf (FID, '%f    ', md_arytenoid);

    % fprintf (FID, '%f    ', max_ues);

    % fprintf (FID, '%f    ', mean_c2c4);

    % fprintf (FID, '%f    ', max_epglts_angle_from_initial);
    % fprintf (FID, '%f    ', max_epglts_angle_from_y);

    % Velocities
    % fprintf (FID, '%f    ', vv_hyoid);
    % fprintf (FID, '%f    ', hv_hyoid);
    % fprintf (FID, '%f    ', mv_hyoid);

    % fprintf (FID, '%f    ', vv_larynx);
    % fprintf (FID, '%f    ', hv_larynx);
    % fprintf (FID, '%f    ', mv_larynx);

    % fprintf (FID, '%f    ', vv_arytenoid);
    % fprintf (FID, '%f    ', hv_arytenoid);
    % fprintf (FID, '%f    ', mv_arytenoid);

    % fprintf (FID, '%f    ', v_max_epglts);

    % fprintf (FID, '%f  \n', mv_bolus);

    % fclose (FID);
  end


  %%
  %  maximalDisplacementOfMarker
  %
  %  This function calculates vertical, horizontal, and 2D maximal
  %  displacements.
  %
  function [vd, hd, md] = maximalDisplacementOfMarker (self, data)
    % Vertical displacement.
    vd = max (data(2,:)) - min (data(2,:));

    % Horizontal displacement.
    hd = max (data(1,:)) - min (data(1,:));

    % 2D maximal displacement.
    firstPoint = data(:, 1);
    difference = [data(1,:) - firstPoint(1); ...
                  data(2,:) - firstPoint(2) ];
    displacement = sqrt (difference(1,:).^2 + difference(2,:).^2);
    md = max (displacement);
  end


  %%
  %  maximalVelocityOfMarker
  %
  %  This function calculates vertical, horizontal, and 2D maximal
  %  velocities.
  %
  function [mvv, mhv, mv] = maximalVelocityOfMarker (self, data, h)
    count = size(data, 2);

    % Vertical velocity.
    vv = self.approximateVelocity (data(2,:), h);
    mvv = max (vv);

    % Horizontal velocity.
    hv = self.approximateVelocity (data(1,:), h);
    mhv = max (hv);

    % 2D maximal velocity.
    v = sqrt (vv.^2 + hv.^2);
    mv = max (v);
  end


  %%
  %  approximateVelocity
  %
  %  This function calculates approximated velocities of discrete data given.
  %
  %  This function uses two-point approximation formula at mid points:
  %
  %                  f'(x) = (f(x + h) - f(x - h)) / (2h)
  %
  %  At the both end points, it uses the following form:
  %
  %                  f'(x) = (f(x + h) - f(x)) / h
  %
  function v = approximateVelocity (self, data, h)
    count = size (data, 2);
    v = zeros (1, count);

    % First point
    v(1) = (data(2) - data(1))/h;

    % Intermediate points
    for i = 2 : count-1
      v(i) = (data(i+1) - data(i-1))/(2*h);
    end

    % Last point
    v(count) = (data(count) - data(count-1))/h;

  end


  %%
  %  distanceBetweenMarkers
  %
  %  This function calculates maximal and mean distance of markers.
  %
  function [max_d, mean_d] = distanceBetweenMarkers (self, p1, p2)
    difference = p1 - p2;
    distance = sqrt (difference(1,:).^2 + difference(2,:).^2);
    max_d = max (distance);
    mean_d = mean (distance);
  end


  %%
  %  copyMarkerDataUpto
  %
  %  This function copies 'n' marker data from the input 'markers' to
  %  self.markers.
  %
  function copyMarkerDataUpto (self, n, markers)
    % Copy time sequence.
    self.markers.('time')(1, 1:n) = markers.('time')(1, 1:n);

    % Copy marker sequences from the 1st to the nth frame.
    countMarkers = size (self.app.markerDefaults, 1);
    for i = 1 : countMarkers
      key = self.app.markerDefaults{i, 7};
      self.markers.(key)(:, 1:n) = markers.(key)(:, 1:n);
    end
  end


  %%
  %  correctFrameIndicesWithCoinMarkers
  %
  %  This function examines current frame markers and corrects
  %  frameIndicesWithCoinMarkers array accordingly.
  %
  function correctFrameIndicesWithCoinMarkers (self)
    % Determine whether current frame index is already found.
    indices = find (...
      self.frameIndicesWithCoinMarkers == self.mainWindowController.currentFrameIndex);

    % Check whether this frame has coin markers or not.
    coin_anterior_key = self.app.markerKeyCoinAnterior;
    coin_posterior_key = self.app.markerKeyCoinPosterior;
    current = self.mainWindowController.currentFrameIndex;
    if self.markers.(coin_anterior_key)(1, current) ~= 0 && ... % anterior
       self.markers.(coin_anterior_key)(2, current) ~= 0 && ...
       self.markers.(coin_posterior_key)(1, current) ~= 0 && ... % posterior
       self.markers.(coin_posterior_key)(2, current) ~= 0
      % Anterior and posterior coin markers exist in this frame.

      if size (indices, 2) == 0 % Current frame is a new frame with coin
                                % markers.
        self.frameIndicesWithCoinMarkers = ...
          [self.frameIndicesWithCoinMarkers self.mainWindowController.currentFrameIndex];

      end

    else % Current frame does not have coin markers.
      self.frameIndicesWithCoinMarkers (indices) = [];

    end

    % disp (self.frameIndicesWithCoinMarkers)
  end


  %%
  %  loadFrameImage
  %
  %  This function loads a frame which corresponds to the frame counter given.
  %  If the frame was already loaded, this function does nothing.
  %  Otherwise, it loads the frame from video object.
  %
  function ih = loadFrameImage (self, counter)
    self.videoObject.CurrentTime = (counter - 1)/self.frameRate;

    % Load the frame which has never been loaded before
    if ~isgraphics(self.videoFrames(counter))
      ax = axes ('Position', [0 0 0 0]);  % Dummy axes to prevent the flickering of new image.
      imageLoaded = image (ax, rgb2gray (readFrame (self.videoObject)));
      self.videoFrames (counter) = copy (imageLoaded);
      ih = self.videoFrames (counter);

    else
      ih = self.videoFrames (counter);

    end

  end


  %%
  %  frameHasActualMarkersPicked
  %
  %  This function examines whether actual markers are picked or not in
  %  a frame.
  %
  function actualMarkersPicked = frameHasActualMarkersPicked (self, index)
    countMarkers = size (self.app.markerDefaults, 1);
    actualMarkersPicked = false;
    for i = 1:countMarkers
      if norm (self.markers.(self.app.markerDefaults{i, 7})(:, index)) ~= 0
        actualMarkersPicked = true;
        break;
      end
    end
  end


  %%
  %  copyMarkersToCurrentFrame
  %
  %  This function copies markers to current frame if required.
  %
  function copyMarkersToCurrentFrame (self, prevIndex)
    % Copy previous markers when
    %  1. the checkbox is checked, and
    %  2. all the markers in the new frame are set to 0.
    countMarkers = size (self.app.markerDefaults, 1);
    current = self.mainWindowController.currentFrameIndex;
    markersNotPickedInCurrentFrame = true;
    for i = 1:countMarkers
      if norm (self.markers.(self.app.markerDefaults{i, 7})(:, current)) ~= 0
        markersNotPickedInCurrentFrame = false;
        break;
      end
    end


    if markersNotPickedInCurrentFrame
      % This frame does not have any markers picked
      % and the copy markers checkbox is on.

      % Copy the marker data to table view data and model object.
      for i = 1 : countMarkers
        marker_key = self.app.markerDefaults{i, 7};
        self.mainWindowController.markerTable.Data {i, 4} = ...
          self.markers.(marker_key)(1, prevIndex);

        self.markers.(marker_key)(1, current) = ...
          self.markers.(marker_key)(1, prevIndex);

        self.mainWindowController.markerTable.Data {i, 5} = ...
          self.markers.(marker_key)(2, prevIndex);

        self.markers.(marker_key)(2, current) = ...
          self.markers.(marker_key)(2, prevIndex);

        % Mark that the raw trajectory of the marker is editted.
        % (Re-smoothing required later.)
        if self.smoothingParameters.(marker_key)(1) > 0
          self.smoothingParameters.(marker_key)(1) = ...
            -1 * self.smoothingParameters.(marker_key)(1);
        end

      end

      % If enough number of coin markers are selected,
      % we don't have to copy the coin markers to this new frame.
      if size (self.frameIndicesWithCoinMarkers, 2) >= ...
            self.app.pref_coinMarkerSelectionCount

        % Zero coin anterior marker.
        self.mainWindowController.markerTable.Data (1, 2) = num2cell (false);
        self.mainWindowController.markerTable.Data {1, 4} = 0;
        self.mainWindowController.markerTable.Data {1, 5} = 0;

        % Zero coin posterior marker.
        self.mainWindowController.markerTable.Data (2, 2) = num2cell (false);
        self.mainWindowController.markerTable.Data {2, 4} = 0;
        self.mainWindowController.markerTable.Data {2, 5} = 0;

        % Zero model object.
        self.markers.(self.app.markerKeyCoinAnterior)(:, current) = [0; 0];
        self.markers.(self.app.markerKeyCoinPosterior)(:, current) = [0; 0];
      end

      if frameHasActualMarkersPicked (self, current) % Actual markers copied.
        self.markUnsavedChanges ();
      end

    end
  end


  %%
  %  markUnsavedChanges
  %
  %  This function sets unsavedChanges flag and modify GUI accordingly.
  %
  function markUnsavedChanges (self)
    % Mark there is unsaved change.
    self.hasUnsavedChanges = true;

    % Change the title of the window to represent that the file is changes.
    windowTitle = sprintf('%s --- Edited', self.movieFileName);
    self.mainWindowController.setWindowTitle (windowTitle);
  end


  %%
  %  createAnimationWindow
  %
  %  This function creates a new animation window.
  %  If there exist a window already, simply brings it to front.
  %
  function createAnimationWindow (self, smoothing)
    self.animationWindowController.showWindow ();
  end


  %%
  %  trackMarkers
  %
  %  This function automatically tracks markers, given the initial markers.
  %  This function is experimental.
  %
  function trackMarkers (self, beginningIndex)

    % Tweak user interface.
    backup = self.mainWindowController.checkboxCopyMarkers.Value;
    self.mainWindowController.checkboxCopyMarkers.Value = 0;
    self.mainWindowController.checkboxCopyMarkers.Enable = 'off';

    frameImage = self.loadFrameImage (beginningIndex);
    frameIndex = beginningIndex;

    countMarkers = size (self.app.markerDefaults, 1);
    initialPoints = [];
    markersToTrack = [];

    for i = 1 : countMarkers
      marker_key = self.app.markerDefaults{i, 7};
      x = self.markers.(marker_key)(1, frameIndex);
      y = self.markers.(marker_key)(2, frameIndex);

      if x ~= 0 && y ~= 0
        initialPoints = [initialPoints; x y];
        markersToTrack = [markersToTrack; i];
      end
    end

    markersToTrackCount = size (markersToTrack, 1);

    tracker = vision.PointTracker ('MaxBidirectionalError', 1);
    initialize (tracker, initialPoints, frameImage.CData);

    while frameIndex < self.frameCount  % For each frame remaining
      frameIndex = frameIndex + 1;
      frameImage = self.loadFrameImage (frameIndex); % Load the next frame

      % Tweak user interface.
      set (self.mainWindowController.sliderTime, 'Value', frameIndex);
      self.mainWindowController.setFrameIndex (frameIndex);

      [pointsTracked, validity] = tracker (frameImage.CData);

      for i = 1 : markersToTrackCount
        marker_key = self.app.markerDefaults{markersToTrack(i), 7};

        if validity(i)  % Tracking to the i'th marker succeeded.
          self.markers.(marker_key)(1, frameIndex) = round (pointsTracked (i, 1));
          self.markers.(marker_key)(2, frameIndex) = round (pointsTracked (i, 2));
        else
          self.markers.(marker_key)(1, frameIndex) = 0;
          self.markers.(marker_key)(2, frameIndex) = 0;
        end

      end

      self.mainWindowController.currentFrameIndex = frameIndex;
      self.mainWindowController.displayFrameImageLoadingMarkersToTable ();
      self.mainWindowController.drawOverlay ();
    end

    % Restore user interface.
    self.mainWindowController.checkboxCopyMarkers.Value = backup;
    self.mainWindowController.checkboxCopyMarkers.Enable = 'on';
  end

end

end

