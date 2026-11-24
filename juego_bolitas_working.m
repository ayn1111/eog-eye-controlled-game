function juego_bolitas()
    % --- CONFIGURACIÓN E INICIALIZACIÓN ---
    close all; clc;
    
    puertoCOM = 'COM11';   % Puerto Arduino (verifica en el Administrador de dispositivos)
    baudRate = 115200;
    Fs = 50;               % 50 Hz

    % Variables de estado del juego
    puntos = 0;
    bolas_restantes = 50;
    pos_barra = 3;

    % Variables de procesamiento EOG
    lineaBase = 205;      
    umbralD = 35;         
    umbralI = 35;         
    
    % Cooldown de 0.75 s para ignorar el rebote bifásico del filtro paso alto de Vernier
    T_COOLDOWN = 0.75;    
    tBloqueoHasta = -Inf;

    % 2 muestras consecutivas (40 ms): descarta artefactos impulsivos cortos
    N_CONSEC = 2;
    consecD = 0;
    consecI = 0;

    % Buffer para gráfica inferior (últimos 5 segundos)
    numMuestrasPlot = 5 * Fs;
    tPlot = linspace(-5, 0, numMuestrasPlot);
    datosEOGPlot = ones(1, numMuestrasPlot) * lineaBase;

    % Suavizado paso bajo (media móvil de 3 muestras)
    N_SUAVE = 3;
    bufSuave = ones(1, N_SUAVE) * lineaBase;

    % Buffer para línea base dinámica (elimina deriva DC / DC drift removal)
    N_BASE = 75;           % Ventana de 1.5 s a 50 Hz
    bufBase = ones(1, N_BASE) * lineaBase;

    %% --- CONEXIÓN PUERTO SERIE ---
    try
        delete(instrfind); %#ok<REMFF1>
    catch
    end
    s = serialport(puertoCOM, baudRate);
    configureTerminator(s, "LF");
    flush(s);
    cleanupObj = onCleanup(@() delete(s));

    %% --- FASE DE CALIBRACIÓN (3 repeticiones) ---
    calibrar_eog();

    % Reiniciar buffers con la línea base calibrada
    datosEOGPlot = ones(1, numMuestrasPlot) * lineaBase;
    bufSuave = ones(1, N_SUAVE) * lineaBase;
    bufBase = ones(1, N_BASE) * lineaBase;

    %% --- CREAR INTERFAZ DEL JUEGO ---
    fig = figure('Name', 'Juego de Atrapar Bolitas - Control EOG', ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none', ...
                'Position', [150, 60, 750, 680], ...
                'KeyPressFcn', @manejar_teclado, ...
                'Resize', 'off');

    ax_juego = axes('Parent', fig, ...
                    'Position', [0.08, 0.36, 0.55, 0.58], ...
                    'XLim', [0.5, 5.5], ...
                    'YLim', [0, 6], ...
                    'XTick', [], 'YTick', [], ...
                    'Box', 'on', ...
                    'NextPlot', 'add');
    title(ax_juego, 'Atrapa la Bolita (Control EOG)', 'FontSize', 12, 'FontWeight', 'bold');

    for x = 1:5
        plot(ax_juego, [x x], [0 6], ':', 'Color', [0.8 0.8 0.8]);
    end

    h_barra = rectangle(ax_juego, 'Position', [pos_barra - 0.4, 0.3, 0.8, 0.4], ...
                        'FaceColor', [0.2, 0.6, 0.8], 'Curvature', 0.2);

    h_bola = plot(ax_juego, 3, 6, 'o', 'MarkerSize', 18, ...
                  'MarkerFaceColor', [0.9, 0.2, 0.2], 'MarkerEdgeColor', 'k');

    ax_marcador = axes('Parent', fig, ...
                       'Position', [0.68, 0.36, 0.28, 0.58], ...
                       'XLim', [0, 1], 'YLim', [0, 1], ...
                       'Visible', 'off');

    text(ax_marcador, 0.5, 0.85, 'PUNTUACIÓN', 'FontSize', 13, ...
         'FontWeight', 'bold', 'HorizontalAlignment', 'center');
     
    txt_puntos = text(ax_marcador, 0.5, 0.70, '0', 'FontSize', 34, ...
                      'FontWeight', 'bold', 'Color', [0 0.5 0], ...
                      'HorizontalAlignment', 'center');

    text(ax_marcador, 0.5, 0.50, 'Restantes:', 'FontSize', 11, ...
         'HorizontalAlignment', 'center');
     
    txt_restantes = text(ax_marcador, 0.5, 0.40, '50', 'FontSize', 18, ...
                         'HorizontalAlignment', 'center');

    txt_deteccion = text(ax_marcador, 0.5, 0.15, 'CENTRO', 'FontSize', 14, ...
                         'FontWeight', 'bold', 'Color', [0.4 0.4 0.4], ...
                         'HorizontalAlignment', 'center');

    % Mini-Gráfica de Biofeedback
    ax_bio = axes('Parent', fig, 'Position', [0.08, 0.08, 0.88, 0.20]);
    h_plot_eog = plot(ax_bio, tPlot, datosEOGPlot, 'b-', 'LineWidth', 1.2);
    hold(ax_bio, 'on');
    h_base = yline(ax_bio, lineaBase, 'k--', 'Base', 'Alpha', 0.5);
    h_uI   = yline(ax_bio, lineaBase + umbralI, 'g--', 'Umbral Izq', 'LineWidth', 1.1);
    h_uD   = yline(ax_bio, lineaBase - umbralD, 'r--', 'Umbral Der', 'LineWidth', 1.1);
    xlim(ax_bio, [-5, 0]);
    ylim(ax_bio, [max(0, lineaBase - 140), lineaBase + 140]);
    grid(ax_bio, 'on');
    xlabel(ax_bio, 'Tiempo (s)'); ylabel(ax_bio, 'EOG');

    tGlobal = tic;

    %% --- BUCLE PRINCIPAL DEL JUEGO ---
    for b = 1:50
        if ~isvalid(fig), break; end
        
        carril = randi(5);
        bolas_restantes = 50 - b + 1;
        set(txt_restantes, 'String', num2str(bolas_restantes));

        for pos_y_bola = 5:-1:1
            if ~isvalid(fig), break; end
            set(h_bola, 'XData', carril, 'YData', pos_y_bola);
            drawnow;
            
            tInicioPaso = tic;
            while toc(tInicioPaso) < 1.0
                if ~isvalid(fig), break; end
                leer_y_procesar_serie();
                pause(0.01);
            end
        end
        
        if ~isvalid(fig), break; end

        if carril == pos_barra
            puntos = puntos + 1;
            set(txt_puntos, 'String', num2str(puntos));
            set(h_barra, 'FaceColor', [0.2, 0.8, 0.2]);
            esperar_con_lectura(0.25);
            set(h_barra, 'FaceColor', [0.2, 0.6, 0.8]);
        else
            set(h_barra, 'FaceColor', [0.9, 0.2, 0.2]);
            esperar_con_lectura(0.25);
            set(h_barra, 'FaceColor', [0.2, 0.6, 0.8]);
        end
        
        set(h_bola, 'YData', 6);
        drawnow;
    end

    if isvalid(fig)
        set(txt_restantes, 'String', '0');
        msgbox(sprintf('¡Juego terminado!\nPuntuación final: %d / 50', puntos), 'Fin del Juego');
    end

    %% =================================================================
    %%                       FUNCIONES AUXILIARES
    %% =================================================================

    function leer_y_procesar_serie()
        while s.NumBytesAvailable > 0
            linea = readline(s);
            val = str2double(strtrim(linea));
            
            if ~isnan(val)
                % 1. Suavizado paso bajo
                bufSuave = [bufSuave(2:end), val];
                valFilt = mean(bufSuave);

                % 2. Actualización adaptativa de la línea base (solo en reposo)
                tActual = toc(tGlobal);
                if (tActual > tBloqueoHasta) && (abs(valFilt - lineaBase) < 25)
                    bufBase = [bufBase(2:end), valFilt];
                    lineaBase = mean(bufBase);
                end

                % 3. Actualizar gráfica y umbrales dinámicos
                datosEOGPlot = [datosEOGPlot(2:end), valFilt];
                set(h_plot_eog, 'YData', datosEOGPlot);
                set(h_base, 'Value', lineaBase);
                set(h_uI,   'Value', lineaBase + umbralI);
                set(h_uD,   'Value', lineaBase - umbralD);

                % 4. Detección de sacadas con periodo refractario (cooldown)
                if tActual > tBloqueoHasta
                    % Detección DERECHA (primer pico hacia ABAJO)
                    if valFilt < (lineaBase - umbralD)
                        consecD = consecD + 1;
                        consecI = 0;
                        if consecD >= N_CONSEC
                            mover_barra(+1);
                            set(txt_deteccion, 'String', '👉 DERECHA', 'Color', [0 0.7 0]);
                            tBloqueoHasta = tActual + T_COOLDOWN;
                            consecD = 0;
                        end
                        
                    % Detección IZQUIERDA (primer pico hacia ARRIBA)
                    elseif valFilt > (lineaBase + umbralI)
                        consecI = consecI + 1;
                        consecD = 0;
                        if consecI >= N_CONSEC
                            mover_barra(-1);
                            set(txt_deteccion, 'String', '👈 IZQUIERDA', 'Color', [0.8 0 0]);
                            tBloqueoHasta = tActual + T_COOLDOWN;
                            consecI = 0;
                        end
                    else
                        consecD = 0;
                        consecI = 0;
                    end
                else
                    consecD = 0;
                    consecI = 0;
                end
            end
        end
        drawnow limitrate;
    end

    function mover_barra(dir)
        pos_barra = min(5, max(1, pos_barra + dir));
        set(h_barra, 'Position', [pos_barra - 0.4, 0.3, 0.8, 0.4]);
        drawnow;
    end

    function esperar_con_lectura(seg)
        t0 = tic;
        while toc(t0) < seg
            leer_y_procesar_serie();
            pause(0.01);
        end
    end

    function manejar_teclado(~, event)
        switch event.Key
            case 'leftarrow',  mover_barra(-1);
            case 'rightarrow', mover_barra(+1);
        end
    end

    function calibrar_eog()
        figCal = figure('Name', 'Calibración EOG', 'MenuBar', 'none', ...
                        'Position', [300, 300, 520, 240], 'Color', 'w');
        axCal = axes(figCal, 'Visible', 'off');
        txtMsg = text(axCal, 0.5, 0.65, '', 'FontSize', 18, 'FontWeight', 'bold', ...
                      'HorizontalAlignment', 'center');
        txtSub = text(axCal, 0.5, 0.35, '', 'FontSize', 12, 'HorizontalAlignment', 'center');

        % 1. Línea Base (mantener vista fija al centro sin parpadear)
        set(txtMsg, 'String', '👀 MIRA AL CENTRO');
        set(txtSub, 'String', 'Mantén la mirada fija sin parpadear...');
        drawnow;
        muestrasBase = [];
        t0 = tic;
        while toc(t0) < 2.5
            while s.NumBytesAvailable > 0
                v = str2double(strtrim(readline(s)));
                if ~isnan(v), muestrasBase(end+1) = v; end %#ok<AGROW>
            end
            pause(0.01);
        end
        if ~isempty(muestrasBase)
            lineaBase = median(muestrasBase);
        end

        % 2. 3 Repeticiones DERECHA
        picosD = zeros(1, 3);
        for rep = 1:3
            set(txtMsg, 'String', sprintf('👉 DERECHA (%d/3)', rep));
            set(txtSub, 'String', 'Mira a la derecha y vuelve al centro');
            drawnow; beep;
            picoLocal = 0;
            t0 = tic;
            while toc(t0) < 1.6
                while s.NumBytesAvailable > 0
                    v = str2double(strtrim(readline(s)));
                    if ~isnan(v)
                        deflexion = lineaBase - v;
                        if deflexion > picoLocal, picoLocal = deflexion; end
                    end
                end
                pause(0.01);
            end
            picosD(rep) = picoLocal;
            pause(0.4);
        end

        % 3. 3 Repeticiones IZQUIERDA
        picosI = zeros(1, 3);
        for rep = 1:3
            set(txtMsg, 'String', sprintf('👈 IZQUIERDA (%d/3)', rep));
            set(txtSub, 'String', 'Mira a la izquierda y vuelve al centro');
            drawnow; beep;
            picoLocal = 0;
            t0 = tic;
            while toc(t0) < 1.6
                while s.NumBytesAvailable > 0
                    v = str2double(strtrim(readline(s)));
                    if ~isnan(v)
                        deflexion = v - lineaBase;
                        if deflexion > picoLocal, picoLocal = deflexion; end
                    end
                end
                pause(0.01);
            end
            picosI(rep) = picoLocal;
            pause(0.4);
        end

        ampD = max(25, median(picosD));
        ampI = max(25, median(picosI));

        umbralD = max(35, min(55, 0.55 * ampD));
        umbralI = max(35, min(55, 0.55 * ampI));

        set(txtMsg, 'String', '¡CALIBRACIÓN COMPLETADA!');
        set(txtSub, 'String', sprintf('Base: %.0f | Umbral Der: -%.0f | Umbral Izq: +%.0f', lineaBase, umbralD, umbralI));
        drawnow;
        pause(1.5);
        close(figCal);
    end
end