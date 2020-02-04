classdef vfspSmthr < handle
%
%  This class implements various kinds of smoothing of raw data as follows:
%
%    1. Curve fit using polynomials whose degrees ranges from 5th
%    to 15th.
%
%    2. Moving average.
%
%    3. Local regression using weighted linear least squares and a
%    1st degree polynomial model.
%
%    4. Local regression using weighted linear least suqares and a
%    2nd degree polynomial model.
%
%    5. Savitzky-Golay filter.
%
%    6. Robust version of local regression using weighted linear
%    least squares and a 1st degree polynomial model.
%
%    7. Robust version of local regression using weighted linear
%    least squares and a 2nd degree polynomial model.
%
%    
%    All rights reserved.  (c) Changmook Chun.  2015.
%
  
  %
  %  Properties
  %
  properties

    % handles
    %
    app  % main application object
    doc  % document object
    window  % handle to the window object
    sub_controls

    degree_popup
    span_edit
    
    %
    % UI controls (Others)
    %
    markerPopupMenu
    methodPopupMenu    

    % Previously selected item of the popup menus
    prevSelectedMarkerIndex
    prevSelectedMethodIndex
    
    % model objects
    rawTrajectory     % Raw data of trajectory
    plotPositions     % Position vectors of subplots
    threshold 
    methodDescriptions

    positionParameterControls  % Vertical coordinate of controls
                               % for parameters
  end
  
  

  % ----------------------------------------------------------------------------
  %
  %                          P U B L I C    M E T H O D S
  %
  % ----------------------------------------------------------------------------
  methods
    % --------------------------------------------------------------------------
    %
    %  Method: vfspSmthr
    %
    %  This function constructs and initializes a vfspSmthr object.
    %
    % --------------------------------------------------------------------------
    function self = vfspSmthr (theApp, theDoc)
     
      self.app = theApp;
      self.doc = theDoc;

      %  Set smoothing methods and their descriptions
      methodPopupStrings = { ...
        'No smoothing', ...
        'Polynomial curve fitting', ...
        'Moving average', ...
        'LOWESS', ...
        'LOESS', ...
        'Savitzky-Golay filter', ...
        'Robust LOWESS', ...
        'Robust LOESS', ...
        };
      
      self.methodDescriptions = { ...
        ['No smoothing applied to this trajectory.'], ...
        ['Curve fit using a polynomial whose degree ranges from 5th ' ...
         'to 15th.'], ...
        ['Moving average.  A lowpass filter with filter coefficients ' ...
         'equal to the reciprocal of the span.'], ... 
        ['Local regression using weighted linear least squares and ' ...
         'a 1st degree polynomial model.'], ...
        ['Local regression using weighted linear least suqares and ' ...
         'a 2nd degree polynomial model.'], ...
        ['Savitzky-Golay filter.  A generalized moving average with ' ...
         'filter coefficients determined by an unweighted linear ' ...
         'least-squares regression and a polynomial model of specified ' ...
         'degree (default is 2).  The method can accept nonuniform ' ...
         'predictor data.'], ...
        ['A robust version of LOWESS that assigns lower weight to ' ...
         'outliers in the regression.  The method assigns zero weight ' ...
         'to data outside six mean absolute deviations.' ], ...
        ['A robust version of LOESS that assigns lower weight to '...
         'outliers in the regression.  The method assigns zero weight ' ...
         'to data outside six mean absolute deviations.' ], ... 
        };
     

      % Get screen size
      scrsz = get(groot,'ScreenSize');
      screenWidth = scrsz(3);
      screenHeight = scrsz(4);

      windowWidth = screenWidth;
      windowHeight = screenHeight - 100;

      maxWindowWidth = 1280;
      maxWindowHeight = 1024;

      if windowWidth > maxWindowWidth
        windowWidth = maxWindowWidth;
      end 

      if windowHeight > maxWindowHeight
        windowHeight = maxWindowHeight;
      end 

      self.window = figure ('Visible', 'off', ...
          'NumberTitle', 'off', ...
          'MenuBar', 'none', ...
          'ToolBar', 'none', ...
          'Name', 'Polynomial Fitting of the Trajectories', ...
          'WindowStyle', 'modal', ...
          'Resize', 'off', ...
          'Position', [0, 0, windowWidth, windowHeight]);
      
      % Draw controls on the right side of the window.
      distance_btwn_elements = 10;
      control_width = 200;
      control_height = 20;
      
      control_pos_x = windowWidth - control_width - 2*distance_btwn_elements;
      control_pos_top = windowHeight - 2*distance_btwn_elements;
      control_pos_y = control_pos_top - control_height;
      
      % Calculate plot positions.
      width_ratio = (windowWidth - control_width - 2*distance_btwn_elements)...
                    / windowWidth - 0.1;
      self.plotPositions = {};
      self.plotPositions{1} = [0.05, 0.05, width_ratio, 0.42];
      self.plotPositions{2} = [0.05, 0.55, width_ratio, 0.42];
      
      % Create popup menu to select marker.
      % ------------------------------------------------------------------------
      % Label:
      uicontrol (self.window, ...
        'Style', 'text', ...
        'String', 'Select a marker :', ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', ...
        'Position', [control_pos_x  control_pos_y  ...
                     control_width  control_height]);


      % Popup menu:
      popupMenuString = self.createPopupString ();
      control_pos_y = control_pos_y - control_height;

      self.markerPopupMenu = ...
          uicontrol (self.window, ...
                     'Style', 'popup',...
                     'String', popupMenuString,...
                     'Value', 1, ...
                     'Position', [control_pos_x  control_pos_y  ...
                          control_width  control_height ],...
                     'Callback', ...
                     {@(src, event)markerPopupSelected(self, src, event)});


      % Create popup menu to select smoothing method.
      % ------------------------------------------------------------------------
      % Label:
      control_pos_y = control_pos_y - control_height - 50;
      uicontrol (self.window, ...
                 'Style', 'text', ...
                 'String', 'Select a method :', ...
                 'FontWeight', 'bold', ...
                 'HorizontalAlignment', 'left', ...
                 'Position', [control_pos_x  control_pos_y ...
                              control_width  control_height]);
      
      % Popup menu:
      control_pos_y = control_pos_y - control_height;
      self.methodPopupMenu = ...
          uicontrol (self.window, ...
                     'Style', 'popup', ...
                     'String', methodPopupStrings, ...
                     'Value', 1, ...
                     'Position', [control_pos_x  control_pos_y ...
                                  control_width  control_height ], ...
                     'Callback', ...
                     {@(src, event)smoothingMethodChanged(self, src, event)});
    
      % Controls to set parameters of the method:
      control_pos_y = control_pos_y - control_height - 20;
      self.positionParameterControls = [control_pos_x  control_pos_y ...
                                        control_width  control_height];
      self.drawParameterControlsWithDescription ();
    
      % Copy raw trajectories which do not require smoothing.
      self.copyNoSmoothingTrajectories ();

      % Smooth current trajectory.
      self.loadMarkerTrajectory (3);
      self.prevSelectedMarkerIndex = 3;
      % self.smoothTrajectory (self, []);

      % Move the window to the center of the screen.
      movegui (self.window, 'center');
      
      % Make the window current figure.
      figure (self.window);
      
      % Display the window.
      self.window.Visible = 'on';

    end

  end
  

  
 
  % ----------------------------------------------------------------------------
  %
  %                      P R I V A T E    M E T H O D S
  %
  % ----------------------------------------------------------------------------
  methods (Access = private)

    % --------------------------------------------------------------------------
    %
    %  Method: copyNoSmoothingTrajectories
    %
    %  This function copies raw trajectories which do not require smoothing.
    %
    % --------------------------------------------------------------------------
    function copyNoSmoothingTrajectories (self)
      markersCount = size (self.app.markerDefaults, 1);

      for i = 1 : markersCount 
        markerKey = self.app.markerDefaults{i, 7};

        smoothingParameters = self.doc.smoothingParameters.(markerKey);

        if smoothingParameters(1) == 0 % This trajectory does not require 
                                       % smoothing
          self.doc.markersSmoothed.(markerKey) = self.doc.markers.(markerKey);

        end 
      end
    end




    % --------------------------------------------------------------------------
    %
    %  Method: createPopupString
    %
    %  This function creates string cell array for the marker popup menu.
    %  Smoothed markers are prefixed with 'o_'.
    %
    % --------------------------------------------------------------------------
    function popupMenuString = createPopupString (self)
      % Popup menu strings:
      markersCount = size (self.app.markerDefaults, 1);
      popupMenuString = {markersCount};
      
      for i = 3:markersCount  % Skip the first 2 markers (coin anterior/posterior).
        % Mark whether the trajectory is smoothed or not.
        smoothingParameters = ...
          self.doc.smoothingParameters.(self.app.markerDefaults{i, 7});
       
        smoothedMarker = '&#32;';
        if smoothingParameters(1) < 0 % Smoothing required
          smoothedMarker = '&#45;&#45;&#45;&#62;';
        end 

        popupMenuString {i - 2} = sprintf (...
          '<html><font color="#ff0000">%s</font> %s</html>', ...
          smoothedMarker, ...
          self.app.markerDefaults{i,2});

        % popupMenuString {i - 2} = sprintf (...
        %   '<html><font color="#%s%s%s">%s %s</font></html>', ...
        %   self.app.markerDefaults{i,3}, ...
        %   self.app.markerDefaults{i,4}, ...
        %   self.app.markerDefaults{i,5}, ...
        %   smoothedMarker, ...
        %   self.app.markerDefaults{i,2});
      end

    end




    % --------------------------------------------------------------------------
    %
    %  Method: drawParameterControlsWithDescription
    %
    %  This function draws controls to set parameters of smoothing
    %  method.
    %
    % --------------------------------------------------------------------------
    function control_pos_y = drawParameterControlsWithDescription (self)

      methodIndex = get(self.methodPopupMenu, 'Value');
      
      control_pos_x = self.positionParameterControls (1);
      control_pos_y = self.positionParameterControls (2);
      control_width = self.positionParameterControls (3);
      control_height = self.positionParameterControls (4);
      
      % 'Parameters :' label.
      uicontrol (self.window, ...
                 'Style', 'text', ...
                 'String', 'Parameters :', ...
                 'FontWeight', 'bold', ...
                 'HorizontalAlignment', 'left', ...
                 'Position', [control_pos_x  control_pos_y ...
                              control_width  control_height]);
      
      % Delete sub_controls
      for i = 1 : size(self.sub_controls, 2)
        delete (self.sub_controls(i));
      end
      self.sub_controls = [];      
      
      % Draw parameters accordingly
      % ------------------------------------------------------------------------
      
      % Set dimension:
      %
      %  (control_pos_x, control_pos_y)
      %  .
      %  | <----------------- control_width --------------------> |
      %  |                                                        |
      %  |      . (sub_control_pos_x, ...)                        |
      %  |      |                           . (sub_control_pos_x, ...)
      %  | <--> | <----------------> | <--> | <-----------------> |
      %     |           |               |         |
      %    sub_indent   |               |         |
      %                 |               |         |
      %              sub_label_width    |         |
      %                                 |         |
      %             sub_label_control_gap_width   |
      %                                           |
      %                                   sub_control_width
      %      
      sub_indent = 20;
      sub_label_pos_x = control_pos_x + sub_indent;
      sub_label_width = 80;
      sub_label_control_gap_width = 10;
      sub_control_pos_x = control_pos_x + sub_label_width + ...
          sub_label_control_gap_width; 
      sub_control_width = control_width - sub_indent - ...
          sub_label_width - sub_label_control_gap_width;
      sub_pos_y = control_pos_y;
      sub_height = control_height;
      
      switch (methodIndex - 1)  % The first menu item is 'no smoothing'
        case 0 % Do nothing.

        case 1 % Polynomial curve fitting
          % Label for degree popup menu.
          sub_pos_y = sub_pos_y - sub_height;
          h = uicontrol (self.window, ...
                         'Style', 'text', ...
                         'String', 'Degree :', ...
                         'FontWeight', 'bold', ...
                         'HorizontalAlignment', 'left', ...
                         'Position', [sub_label_pos_x  sub_pos_y ...
                              sub_label_width  sub_height]);
          self.sub_controls = [self.sub_controls h];
          
          self.degree_popup ...
            = uicontrol (self.window, ...
                         'Style', 'popup', ...
                         'String', {'5','6','7','8','9','10','11', ...
                              '12','13','14','15'}, ...
                         'Position', [sub_control_pos_x  sub_pos_y ...
                              sub_control_width  sub_height], ...
                         'Callback', ...
                         {@(src, event)smoothTrajectory(self, src, event)});
          
          self.sub_controls = [self.sub_controls self.degree_popup];
          
          
        case 2 % Moving average
          % Label for span text edit.
          sub_pos_y = sub_pos_y - sub_height;
          h = uicontrol (self.window, ...
                         'Style', 'text', ...
                         'String', 'Span :', ...
                         'FontWeight', 'bold', ...
                         'HorizontalAlignment', 'left', ...
                         'Position', [sub_label_pos_x  sub_pos_y ...
                              sub_label_width  sub_height]);
          self.sub_controls = [self.sub_controls h];
          
          self.span_edit ...
            = uicontrol (self.window, ...
                         'Style', 'edit', ...
                         'String', '5', ...
                         'Position', [sub_control_pos_x  sub_pos_y ...
                              sub_control_width  sub_height], ...
                         'Callback', ...
                         {@(src, event)smoothTrajectory(self, src, ...
                                                        event)});
          
          self.sub_controls = [self.sub_controls self.span_edit];
          
          
        case 3 % LOWESS
          % Label for span text edit.
          sub_pos_y = sub_pos_y - sub_height;
          h = uicontrol (self.window, ...
                         'Style', 'text', ...
                         'String', 'Span :', ...
                         'FontWeight', 'bold', ...
                         'HorizontalAlignment', 'left', ...
                         'Position', [sub_label_pos_x  sub_pos_y ...
                              sub_label_width  sub_height]);
          self.sub_controls = [self.sub_controls h];
          
          self.span_edit ...
            = uicontrol (self.window, ...
                         'Style', 'edit', ...
                         'String', '0.1', ...
                         'Position', [sub_control_pos_x  sub_pos_y ...
                              sub_control_width  sub_height], ...
                         'Callback', ...
                         {@(src, event)smoothTrajectory(self, src, ...
                                                        event)});
          
          self.sub_controls = [self.sub_controls self.span_edit];
          
          
        case 4 % LOESS
          % Label for span text edit.
          sub_pos_y = sub_pos_y - sub_height;
          h = uicontrol (self.window, ...
                         'Style', 'text', ...
                         'String', 'Span :', ...
                         'FontWeight', 'bold', ...
                         'HorizontalAlignment', 'left', ...
                         'Position', [sub_label_pos_x  sub_pos_y ...
                              sub_label_width  sub_height]);
          self.sub_controls = [self.sub_controls h];
          
          self.span_edit ...
            = uicontrol (self.window, ...
                         'Style', 'edit', ...
                         'String', '0.1', ...
                         'Position', [sub_control_pos_x  sub_pos_y ...
                              sub_control_width  sub_height], ...
                         'Callback', ...
                         {@(src, event)smoothTrajectory(self, src, ...
                                                        event)});
          
          self.sub_controls = [self.sub_controls self.span_edit];
          
          
        case 5 % Savitzky-Golay filter
          % Label for span text edit.
          sub_pos_y = sub_pos_y - sub_height;
          h = uicontrol (self.window, ...
                         'Style', 'text', ...
                         'String', 'Span :', ...
                         'FontWeight', 'bold', ...
                         'HorizontalAlignment', 'left', ...
                         'Position', [sub_label_pos_x  sub_pos_y ...
                              sub_label_width  sub_height]);
          self.sub_controls = [self.sub_controls h];
          
          self.span_edit ...
            = uicontrol (self.window, ...
                         'Style', 'edit', ...
                         'String', '5', ...
                         'Position', [sub_control_pos_x  sub_pos_y ...
                              sub_control_width  sub_height], ...
                         'Callback', ...
                         {@(src, event)sgolaySpanChanged(self, src, ...
                                                        event)});
          
          self.sub_controls = [self.sub_controls self.span_edit];
          
          % Label for degree text edit.
          sub_pos_y = sub_pos_y - sub_height - 5;
          h = uicontrol (self.window, ...
                         'Style', 'text', ...
                         'String', 'Degree :', ...
                         'FontWeight', 'bold', ...
                         'HorizontalAlignment', 'left', ...
                         'Position', [sub_label_pos_x  sub_pos_y ...
                              sub_label_width  sub_height]);
          self.sub_controls = [self.sub_controls h];
          
          self.degree_popup ...
            = uicontrol (self.window, ...
                         'Style', 'popup', ...
                         'String', {'0', '1', '2', '3', '4'}, ...
                         'Position', [sub_control_pos_x  sub_pos_y ...
                              sub_control_width  sub_height], ...
                         'Callback', ...
                         {@(src, event)smoothTrajectory(self, src, ...
                                                        event)});
          
          self.sub_controls = [self.sub_controls self.degree_popup];
          
          
        case 6 % Robust LOWESS
          % Label for span text edit.
          sub_pos_y = sub_pos_y - sub_height;
          h = uicontrol (self.window, ...
                         'Style', 'text', ...
                         'String', 'Span :', ...
                         'FontWeight', 'bold', ...
                         'HorizontalAlignment', 'left', ...
                         'Position', [sub_label_pos_x  sub_pos_y ...
                              sub_label_width  sub_height]);
          self.sub_controls = [self.sub_controls h];
          
          self.span_edit ...
            = uicontrol (self.window, ...
                         'Style', 'edit', ...
                         'String', '0.1', ...
                         'Position', [sub_control_pos_x  sub_pos_y ...
                              sub_control_width  sub_height], ...
                         'Callback', ...
                         {@(src, event)smoothTrajectory(self, src, ...
                                                        event)});
          
          self.sub_controls = [self.sub_controls self.span_edit];
          
          
        case 7 % Robust LOESS
          % Label for span text edit.
          sub_pos_y = sub_pos_y - sub_height;
          h = uicontrol (self.window, ...
                         'Style', 'text', ...
                         'String', 'Span :', ...
                         'FontWeight', 'bold', ...
                         'HorizontalAlignment', 'left', ...
                         'Position', [sub_label_pos_x  sub_pos_y ...
                              sub_label_width  sub_height]);
          self.sub_controls = [self.sub_controls h];
          
          self.span_edit ...
            = uicontrol (self.window, ...
                         'Style', 'edit', ...
                         'String', '0.1', ...
                         'Position', [sub_control_pos_x  sub_pos_y ...
                              sub_control_width  sub_height], ...
                         'Callback', ...
                         {@(src, event)smoothTrajectory(self, src, ...
                                                        event)});
          
          self.sub_controls = [self.sub_controls self.span_edit];
          
        
        otherwise
          
      end 
      
      control_pos_y = sub_pos_y;
      
      % 'Description :' label.
      control_pos_y = control_pos_y - 30;
      h = uicontrol (self.window, ...
                     'Style', 'text', ...
                     'String', 'Description :', ...
                     'FontWeight', 'bold', ...
                     'HorizontalAlignment', 'left', ...
                     'Position', [control_pos_x  control_pos_y ...
                          control_width  control_height]);
      self.sub_controls = [self.sub_controls h];
      
      % Description text string.
      descriptionTextBoxHeight = 120;
      control_pos_y = control_pos_y - descriptionTextBoxHeight;
      h = uicontrol (self.window, ...
                     'Style', 'text', ...
                     'HorizontalAlignment', 'left', ...
                     'String', self.methodDescriptions(methodIndex), ...
                     'Position', [control_pos_x  control_pos_y ...
                                  control_width  descriptionTextBoxHeight]);          
      self.sub_controls = [self.sub_controls h];
      
      % Create slider control to change threshold.
      if methodIndex > 0
        control_pos_y = control_pos_y - control_height - 50;
        h = uicontrol (self.window, ...
          'Style', 'text', ...
          'String', 'Tune threshold :', ...
          'FontWeight', 'bold', ...
          'HorizontalAlignment', 'left', ...
          'Position', [control_pos_x  control_pos_y  ...
                       control_width  control_height]);
        self.sub_controls = [self.sub_controls h];
        
        control_pos_y = control_pos_y - control_height;
        threshold_max = 15;
        self.threshold = threshold_max;
        h = uicontrol (self.window, ...
          'Style', 'slider', ...
          'Min', 0.1, ...
          'Max', threshold_max, ...
          'Value', threshold_max, ...
          'Position', [control_pos_x  control_pos_y  ...
                       control_width  control_height], ...
          'Callback', {@(src, event)thresholdSliderClicked(self, src, event)});
        self.sub_controls = [self.sub_controls h];
          
        control_pos_y = control_pos_y - control_height;
        h = uicontrol (self.window, ...
          'Style', 'text', ...
          'String', 'Narrower', ...
          'HorizontalAlignment', 'left', ...
          'Position', [control_pos_x  control_pos_y  ...
                       control_width  control_height]);
        self.sub_controls = [self.sub_controls h];

        h = uicontrol (self.window, ...
          'Style', 'text', ...
          'String', 'Wider', ...
          'HorizontalAlignment', 'right', ...
          'Position', [control_pos_x+control_width-50  control_pos_y  ...
                       50  control_height]);
        self.sub_controls = [self.sub_controls h];

      end
      
    end
    
    
    
    
    % --------------------------------------------------------------------------
    %
    %  Method: smoothTrajectory
    %
    %  This function smooths current trajectory.
    %
    % --------------------------------------------------------------------------
    function smoothTrajectory (self, src, event)
      markerIndex = get (self.markerPopupMenu, 'Value') + 2;
      markerKey = self.app.markerDefaults{markerIndex, 7};
      methodIndex = get (self.methodPopupMenu, 'Value');
      
      x = self.doc.markers.('time');
      
      y1 = self.rawTrajectory (1, :);
      y2 = self.rawTrajectory (2, :);
      
      f1 = [];
      f2 = [];
      
      switch (methodIndex - 1)  % The first item is 'no smoothing'
        case 0 % No smoothing
          f1 = y1;
          f2 = y2;


        case 1 % Polynomial curve fitting
          degree = get (self.degree_popup, 'Value');
          degree = degree + 4;
          
          % Fit with polynomial.
          p1 = polyfit (x, y1, degree);
          p2 = polyfit (x, y2, degree);

          % Evaluate the polynomial fit.
          f1 = polyval (p1, x);
          f2 = polyval (p2, x);
          
          
        case 2 % Moving average
          span_string = get (self.span_edit, ...
                             'String');
          
          [span, status] = str2num (span_string);
          
          if status == 0 || span < 1 || size(x, 2) < span 
            % Error in the conversion
            % Set default value of 5.
            
            % First, disable temporarily callback function to
            % prevent infinite loop of callbacks.
            set (self.span_edit, 'Callback', '');
            
            % Second, change the value to default one.
            set (self.span_edit, 'String', '5');
            span = 5;
            
            % Third, recover the callback.
            set (self.span_edit, ...
                 'Callback', ...
                 {@(src, event)smoothTrajectory(self, src, event)});
          end 
          
          f1 = smooth (y1', span);
          f2 = smooth (y2', span);
          
          f1 = f1';
          f2 = f2';
          
           
        case 3 % LOWESS
          span_string = get (self.span_edit, ...
                             'String');
          
          [span, status] = str2num (span_string);
          
          if status == 0 || span < 0. || 1. < span 
            % Error in the conversion
            % Set default value of 0.1.
            
            % First, disable temporarily callback function to
            % prevent infinite loop of callbacks.
            set (self.span_edit, 'Callback', '');
            
            % Second, change the value to default one.
            set (self.span_edit, 'String', '0.1');
            span = 0.1;
            
            % Third, recover the callback.
            set (self.span_edit, ...
                 'Callback', ...
                 {@(src, event)smoothTrajectory(self, src, event)});
          end 
          
          f1 = smooth (y1', span, 'lowess');
          f2 = smooth (y2', span, 'lowess');
          
          f1 = f1';
          f2 = f2';
          
          
        case 4 % LOESS
          span_string = get (self.span_edit, ...
                             'String');
          
          [span, status] = str2num (span_string);
          
          if status == 0 || span < 0. || 1. < span 
            % Error in the conversion
            % Set default value of 0.1.
            
            % First, disable temporarily callback function to
            % prevent infinite loop of callbacks.
            set (self.span_edit, 'Callback', '');
            
            % Second, change the value to default one.
            set (self.span_edit, 'String', '0.1');
            span = 0.1;
            
            % Third, recover the callback.
            set (self.span_edit, ...
                 'Callback', ...
                 {@(src, event)smoothTrajectory(self, src, event)});
          end 
          
          f1 = smooth (y1', span, 'loess');
          f2 = smooth (y2', span, 'loess');
          
          f1 = f1';
          f2 = f2';
          
          
        case 5 % Savitzky-Golay filter
          span_string = get (self.span_edit, ...
                             'String');
          [span, status] = str2num (span_string);
          
          degree = get (self.degree_popup, ...
                        'Value') - 1;
          
          f1 = smooth (y1', span, 'sgolay', degree);
          f2 = smooth (y2', span, 'sgolay', degree);
          
          f1 = f1';
          f2 = f2';
          
          
        case 6 % Robust LOWESS
          span_string = get (self.span_edit, ...
                             'String');
          
          [span, status] = str2num (span_string);
          
          if status == 0 || span < 0. || 1. < span 
            % Error in the conversion
            % Set default value of 0.1.
            
            % First, disable temporarily callback function to
            % prevent infinite loop of callbacks.
            set (self.span_edit, 'Callback', '');
            
            % Second, change the value to default one.
            set (self.span_edit, 'String', '0.1');
            span = 0.1;
            
            % Third, recover the callback.
            set (self.span_edit, ...
                 'Callback', ...
                 {@(src, event)smoothTrajectory(self, src, event)});
          end 
          
          f1 = smooth (y1', span, 'rlowess');
          f2 = smooth (y2', span, 'rlowess');
          
          f1 = f1';
          f2 = f2';
          
          
        case 7 % Robust LOESS
          span_string = get (self.span_edit, ...
                             'String');
          
          [span, status] = str2num (span_string);
          
          if status == 0 || span < 0. || 1. < span 
            % Error in the conversion
            % Set default value of 0.1.
            
            % First, disable temporarily callback function to
            % prevent infinite loop of callbacks.
            set (self.span_edit, 'Callback', '');
            
            % Second, change the value to default one.
            set (self.span_edit, 'String', '0.1');
            span = 0.1;
            
            % Third, recover the callback.
            set (self.span_edit, ...
                 'Callback', ...
                 {@(src, event)smoothTrajectory(self, src, event)});
          end 
          
          f1 = smooth (y1', span, 'rloess');
          f2 = smooth (y2', span, 'rloess');
          
          f1 = f1';
          f2 = f2';
          
        otherwise
          
      end
     
      if methodIndex > 1
        % Mark that this trajectory is smoothed.
        self.doc.smoothingParameters.(markerKey)(1) = ...
          -1 * self.doc.smoothingParameters.(markerKey)(1);

        % Calculate region to fill.
        f1_upper = f1 + self.threshold;
        f1_lower = f1 - self.threshold;
        
        f2_upper = f2 + self.threshold;
        f2_lower = f2 - self.threshold;
        
        Y1 = [f1_lower, fliplr(f1_upper)];
        Y2 = [f2_lower, fliplr(f2_upper)];
        
        X = [x, fliplr(x)];
        
        % Plot.
        subplot ('Position', self.plotPositions{1});
        fill (X, Y1, [.5, .5, 1.]);
        hold on;
        plot (x, y1, 'o', 'MarkerSize', 5);  % Raw trajectory
        plot (x, f1);
        hold off;
        legend ('Region in threshold', 'Picked position', 'Fitted trajectory');
        legend ('boxoff');
        
        
        subplot ('Position', self.plotPositions{2});
        fill (X, Y2, [.5, .5, 1.]);
        hold on;
        plot (x, y2, 'o', 'MarkerSize', 5);  % Raw trajectory
        plot (x, f2);
        hold off;
        legend ('Region in threshold', 'Picked position', 'Fitted trajectory');
        legend ('boxoff');
   
      else % No smoothing.  Simply show the original trajectory
        subplot ('Position', self.plotPositions{1});
        plot (x, y1, 'o', 'MarkerSize', 5);

        subplot ('Position', self.plotPositions{2});
        plot (x, y2, 'o', 'MarkerSize', 5);

      end 

      self.saveCurrentSmoothing (f1, f2);

    end
    
    
    
    
    % --------------------------------------------------------------------------
    %
    %  Method: drawCurrentTrajectories
    %
    %  This function draws current trajectory.
    %
    % --------------------------------------------------------------------------
    function drawCurrentTrajectories (self)
      x = self.doc.markers.('time');
      
      subplot ('Position', self.plotPositions{1});
      plot (x, self.rawTrajectory(1,:), 'o', 'MarkerSize', 5);
      legend ('Picked position');
      legend ('boxoff');
      
      subplot ('Position', self.plotPositions{2});
      plot (x, self.rawTrajectory(2,:), 'o', 'MarkerSize', 5);
      legend ('Picked position');
      legend ('boxoff');
      
    end




    % --------------------------------------------------------------------------
    % 
    %  Method: sgolaySpanChanged
    %
    %  This function is called when the span text edit field of
    %  Savitzky-Golay filter is changed.
    %
    % --------------------------------------------------------------------------
    function sgolaySpanChanged (self, src, event)
      x = self.doc.markers.('time');
      
      span_string = get (self.span_edit, ...
                         'String');
      
      [span, status] = str2num (span_string);
      
      if status == 0 || span < 3 || size(x, 2) < span 
        % Error in the conversion
        % Set default value of 5.
        
        % First, disable temporarily callback function to
        % prevent infinite loop of callbacks.
        set (self.span_edit, 'Callback', '');
        
        % Second, change the value to default one.
        set (self.span_edit, 'String', '5');
        span = 5;
        
        % Third, recover the callback.
        set (self.span_edit, ...
             'Callback', ...
             {@(src, event)sgolaySpanChanged(self, src, event)});
      end 

      % Adjust degree popup menu.
      popup_items = [0 : span-1];
      popup_strings = {};
      for i = 1:size(popup_items,2)
        popup_strings {i} = num2str(popup_items(i));
      end
     
      set (self.degree_popup, 'String', popup_strings);
      set (self.degree_popup, 'Value', 1);
      
      self.smoothTrajectory (src, event);
      
    end
  


    
    % --------------------------------------------------------------------------
    % 
    %  Method: markerPopupSelected
    %
    %  This function is called when a marker set is chosen from the popup menu.
    %
    % --------------------------------------------------------------------------
    function markerPopupSelected (self, src, event)
      markerIndex = get(src, 'Value') + 2; % To skip coin
                                           % anterior/posterior markers.

      if self.prevSelectedMarkerIndex ~= markerIndex
        self.loadMarkerTrajectory (markerIndex);
        self.prevSelectedMarkerIndex = markerIndex;

      end
        
    end
  


    
    % --------------------------------------------------------------------------
    %
    %  Method: setControls
    %
    %  This function sets UI controls according to smoothing parameters.
    %
    % --------------------------------------------------------------------------
    function setControls (self, params)
      method = abs (params (1));

      % Set method popup menu
      % The first menu item is 'no smoothig'
      set (self.methodPopupMenu, 'Value', method + 1);
      
      % Draw other controls
      self.drawParameterControlsWithDescription ();
      
      % Set controls
      switch method 
        case 0 % Nothing to do here.

        case 1 % Polynomial curve fitting
          degree = params (2);
          set (self.degree_popup, 'Value', degree - 4);
          
        case 2 % Moving average
          span = params (2);
          set (self.span_edit, 'String', num2str(span));
          
        case 3 % LOWESS
          span = params (2);
          set (self.span_edit, 'String', num2str(span));
          
        case 4 % LOESS
          span = params (2);
          set (self.span_edit, 'String', num2str(span));
          
        case 5 % Savitzky-Golay filter
          span = params (2);
          set (self.span_edit, 'String', num2str(span));
          
          degree = params (3);
          set (self.degree_popup, 'Value', degree + 1);
          
        case 6 % Robust LOWESS
          span = params (2);
          set (self.span_edit, 'String', num2str(span));
          
        case 7 % Robust LOESS
          span = params (2);
          set (self.span_edit, 'String', num2str(span));
          
      end
      
      % Display smoothed trajectory
      self.smoothTrajectory ([], []);
      
    end
    
    
    
    
    % --------------------------------------------------------------------------
    % 
    %  Method: smoothingMethodChanged
    %
    %  This function is called when smoothing method is changed.
    %
    % --------------------------------------------------------------------------
    function smoothingMethodChanged (self, src, event)
      methodIndex = get(src, 'Value');

      if self.prevSelectedMethodIndex ~= methodIndex
        self.drawParameterControlsWithDescription ();
        self.smoothTrajectory (src, event);

      end

    end
    
    
    
    
    % --------------------------------------------------------------------------
    %
    %  Method: loadMarkerTrajectory
    %
    %  This function loads trajectory of the marker selected.
    %
    % --------------------------------------------------------------------------
    function loadMarkerTrajectory (self, index)
      self.rawTrajectory = ...
        self.doc.markers.(self.app.markerDefaults{index, 7})(1:2, :);

      % Load smoothed trajectory (if any) and set controls according
      % to the smoothing parameters related.
      smoothingParameters = ...
        self.doc.smoothingParameters.(self.app.markerDefaults{index, 7});
     
      self.prevSelectedMethodIndex = abs (smoothingParameters (1));

      self.setControls (smoothingParameters);
        
    end




    % --------------------------------------------------------------------------
    % 
    %  Method: thresholdSliderClicked
    %
    %  This function is called when smoothness slider is changed.
    %
    % --------------------------------------------------------------------------
    function thresholdSliderClicked (self, src, event)
      self.threshold = get(src, 'Value');
      self.smoothTrajectory ();
    end




    % --------------------------------------------------------------------------
    % 
    %  Method: discardSmoothing
    %
    %  This function discards current curve fitting.
    %
    % --------------------------------------------------------------------------
    function discardSmoothing (self, markerIndex)
      
      % Discard smoothing parameters.
      self.doc.smoothingParameters.(self.app.markerDefaults{markerIndex, 7}) ... 
        = zeros (1, 5);

      % Discard smoothed trajectory.
      self.doc.markersSmoothed.(self.app.markerDefaults{markerIndex, 7}) ...  
        = zeros (2, self.doc.frameCount);
      
      % Draw raw trajectory.
      self.drawCurrentTrajectories ();
    end
  



    % --------------------------------------------------------------------------
    % 
    %  Method: saveCurrentSmoothing
    %
    %  This function accepts current curve fitting.
    %
    % --------------------------------------------------------------------------
    function saveCurrentSmoothing (self, f1, f2)
      % ------------------------------------------------------------------------
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
      
      markerIndex = get (self.markerPopupMenu, 'Value') + 2; % To skip coin
                                                             % anterior/posterior markers 
      self.doc.smoothingParameters.(self.app.markerDefaults{markerIndex, 7}) ... 
        = zeros (1, 5);
      
      % Method:
      method = get (self.methodPopupMenu, 'Value') - 1;
      self.doc.smoothingParameters.(self.app.markerDefaults{markerIndex, 7})(1) ...
        = method; 
      
      % Parameters:
      switch method
        case 0 % No smoothing 
          self.discardSmoothing (markerIndex);

        case 1 % Polynomial curve fitting
          degree = get (self.degree_popup, 'Value') + 4;
          self.doc.smoothingParameters.(self.app.markerDefaults{markerIndex, 7})(2) ...
            = degree;
          
        case 2 % Moving average
          span = str2num (get (self.span_edit, 'String'));
          self.doc.smoothingParameters.(self.app.markerDefaults{markerIndex, 7})(2) ...
            = span;
          
        case 3 % LOWESS
          span = str2num (get (self.span_edit, 'String'));
          self.doc.smoothingParameters.(self.app.markerDefaults{markerIndex, 7})(2) ...
            = span;
          
        case 4 % LOESS
          span = str2num (get (self.span_edit, 'String'));
          self.doc.smoothingParameters.(self.app.markerDefaults{markerIndex, 7})(2) ...
            = span;
          
        case 5 % Savitzky-Golay filter
          span = str2num (get (self.span_edit, 'String'));
          self.doc.smoothingParameters.(self.app.markerDefaults{markerIndex, 7})(2) ...          
            = span;
          
          degree = get (self.degree_popup, 'Value') - 1;
          self.doc.smoothingParameters.(self.app.markerDefaults{markerIndex, 7})(3) ...
            = degree;
          
        case 6 % Robust LOWESS
          span = str2num (get (self.span_edit, 'String'));
          self.doc.smoothingParameters.(self.app.markerDefaults{markerIndex, 7})(2) ...
            = span;
          
        case 7 % Robust LOESS
          span = str2num (get (self.span_edit, 'String'));
          self.doc.smoothingParameters.(self.app.markerDefaults{markerIndex, 7})(2) ...
            = span;
      end
      
      % Smoothed trajectory
      % [f1, f2] = self.smoothTrajectory ();
      self.doc.markersSmoothed.(self.app.markerDefaults{markerIndex, 7}) ...  
        = [f1; f2];

      % Re-generate popup menu strings
      popupMenuString = self.createPopupString ();
      set (self.markerPopupMenu, 'String', popupMenuString);
    end
  



  end
  
end
