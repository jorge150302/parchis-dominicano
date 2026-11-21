import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../service/prefs_service.dart';
//Comentario para version buena final
enum Language { en, es }

class LanguageProvider extends ChangeNotifier {
  Language _currentLanguage = Language.es;

  Language get currentLanguage => _currentLanguage;

  LanguageProvider() {
    _loadLanguage();
  }

  void _loadLanguage() {
    if (!PrefsService.hasLanguagePreference) {
      // First launch: detect from device locale.
      // Supported: 'es' → Spanish, everything else → English.
      final deviceLang = ui.PlatformDispatcher.instance.locale.languageCode;
      _currentLanguage = deviceLang == 'es' ? Language.es : Language.en;
      // Persist so the next launch skips detection.
      PrefsService.setLanguage(_currentLanguage.name);
    } else {
      final langCode = PrefsService.languageCode;
      _currentLanguage = langCode == 'en' ? Language.en : Language.es;
    }
  }

  Future<void> setLanguage(Language language) async {
    if (_currentLanguage == language) return;
    _currentLanguage = language;
    await PrefsService.setLanguage(language.name);
    notifyListeners();
  }

  String translate(String key, {Map<String, String>? args}) {
    String translation = _translations[_currentLanguage]?[key] ?? key;
    if (args != null) {
      args.forEach((placeholder, value) {
        translation = translation.replaceAll('{$placeholder}', value);
      });
    }
    return translation;
  }

  @visibleForTesting
  static Map<Language, Map<String, String>> get translations => _translations;

  static const Map<Language, Map<String, String>> _translations = {
    Language.es: {
      'waiting_players': 'Esperando Jugadores...',
      'room_code': 'Código',
      'code_copied': '¡Código copiado!',
      'online': '● EN LÍNEA',
      'offline': '○ DESCONECTADO',
      'reconnecting': '⏳ RECONECTANDO...',
      'chat_unavailable': 'Chat pronto disponible',
      'chat_input_hint': 'Escribe un mensaje...',
      'podium_title': '🏆 PODIO FINAL 🏆',
      'back_to_menu': 'Volver al Menú',
      'connection_lost': 'Conexión Perdida',
      'server_connection_lost': 'Se ha perdido la conexión con el servidor.',
      'exit': 'Salir',
      'select_mode': 'Seleccionar modalidad de juego',
      'offline_mode': 'Sin conexión',
      'offline_subtitle': 'Juega cerca de ti',
      'online_mode': 'En línea',
      'online_subtitle': 'Juega a distancia',
      'settings': 'Ajustes',
      'language': 'Idioma',
      'spanish': 'Español',
      'english': 'Inglés',
      'close': 'Cerrar',
      'player': 'Jugador',
      'select_player_count': 'Seleccionar cantidad de jugadores',
      'play_vs_ai': 'Jugar contra IA',
      'ai_info_content': 'Al activar esta opción, los espacios vacíos serán ocupados por jugadores controlados por la máquina.',
      'start_game': 'COMENZAR JUEGO',
      'back': '← Volver',
      'players_count': 'jugadores',
      'multiplayer_online': 'Multijugador en Línea',
      'quick_match': '⚡ PARTIDA RÁPIDA',
      'quick_match_subtitle': 'Busca rivales ahora',
      'play_with_friends': 'Jugar con Amigos',
      'play_with_friends_subtitle': 'Crea o únete a salas',
      'create_new_room': '➕ CREAR NUEVA SALA',
      'private_code': 'CÓDIGO PRIVADO',
      'join_by_code': 'UNIRSE POR CÓDIGO',
      'leave_room': 'SALIR DE LA SALA',
      'waiting_room': 'SALA DE ESPERA',
      'waiting_room_subtitle': 'El juego iniciará cuando la sala esté llena.',
      'ai_fill_offer': 'Nadie más se ha unido todavía.',
      'ai_fill_button': 'JUGAR AHORA CONTRA LA IA',
      'ai_fill_xp_hint': 'Los asientos vacíos se llenan con IA. Esta partida da la mitad de XP.',
      'name_hint': 'TU NOMBRE',
      'enter_name_title': '¿Cómo te llamas?',
      'rejoin_match': 'VOLVER A PARTIDA',
      'no_matches_found': 'Sin partidas disponibles',
      'no_matches_content': 'No hay salas públicas esperando en este momento.',
      'play_offline': 'Jugar Offline',
      'create_my_room': 'Crear mi Sala',
      'configure_room': 'Configurar nueva sala',
      'public_room': 'Sala Pública',
      'public_room_subtitle': 'Permitir que desconocidos se unan',
      'search_quick_match': 'Buscar Partida Rápida',
      'enter_name_error': 'Introduce tu nombre',
      'all_names_mandatory': 'Deben llenarse todos los campos de nombre',
      'name_code_error': 'Nombre y código obligatorios',
      'your_turn': 'TU TURNO',
      // Board Labels
      'board_start': 'Inicio',
      'board_finish': 'Fin',
      'board_go_to_start': 'INICIO',
      'board_move_to': 'Al {target}',
      'board_skip_turn': 'Turno sin\njugar',
      'board_extra_turn': 'Turno\nextra',
      // Tutorial
      'tutorial': 'Tutorial',
      'tutorial_title': '¿Nuevo en Parché?',
      'tutorial_content': '¿Quieres ver un tutorial rápido para aprender a jugar?',
      'tutorial_start': 'Sí, aprender ahora',
      'tutorial_skip': 'No, ya sé jugar',
      'tutorial_exit_title': 'Terminar Tutorial',
      'tutorial_exit_content': '¿Estás seguro de que quieres abandonar el tutorial? Todo tu progreso actual se perderá.',
      'tut_progress': 'Paso {n} de {total}',
      'tut_you_name': 'Tú',
      'tut_rival_name': 'Azul',
      'tut_skip': 'Saltar',
      'tut_next': 'Siguiente',
      'tut_your_move': 'Tu turno',
      'tut_watch': 'Mira…',
      'tut_goal': '¡Bienvenido! Gana quien lleve primero sus 2 fichas a la META, la última casilla. Te enseño en un minuto.',
      'tut_leave_roll': 'Toca tu dado para tirar.',
      'tut_leave_move': 'Aquí sales de casa con CUALQUIER número. Toca una de tus fichas para sacarla.',
      'tut_six_roll': 'Tira otra vez.',
      'tut_six_move': '¡Un 6! Mueve una ficha… y como sacaste 6, después vuelves a tirar.',
      'tut_six_again': 'El 6 te dio otro tiro. ¡Tira de nuevo!',
      'tut_move_any': 'Toca una ficha para moverla.',
      'tut_roll': 'Toca tu dado para tirar.',
      'tut_capture_intro': '¿Ves la ficha azul 3 casillas delante de la tuya? Si caes justo en su casilla, la capturas.',
      'tut_capture_move': '¡Un 3! Mueve tu ficha de la pista hasta la azul.',
      'tut_capture_done': '¡Capturada! La ficha azul volvió a su casa y tú ganaste un tiro extra.',
      'tut_cells_intro': 'Las casillas naranjas tienen sorpresas. Vamos a caer en una.',
      'tut_cells_roll': 'Lleva tu ficha a la casilla «Turno extra». Toca tu dado.',
      'tut_cells_move': 'Toca tu ficha de la pista.',
      'tut_cell_extra': '«Turno extra»: vuelves a tirar. ¡Por eso sigue siendo tu turno!',
      'tut_cell_skip': '«Pierde turno»: si caes aquí, te saltas tu próximo turno.',
      'tut_cell_start': '«Al inicio»: tu ficha vuelve a casa. ¡Cuidado con esta!',
      'tut_cell_jump': '«Ir a»: te lleva a otra casilla. Esta te sube de la 24 a la 63… pero otras te hacen bajar.',
      'tut_bridge_intro': 'Dos fichas tuyas en la misma casilla forman un PUENTE. Vamos a hacer uno.',
      'tut_bridge_move': 'Mueve tu ficha de atrás para juntarla con la otra.',
      'tut_bridge_done': '¡Puente! Nadie puede pasar ni caer en esa casilla… ni siquiera tú.',
      'tut_bridge_rival': 'Turno del azul…',
      'tut_bridge_blocked': 'El azul sacó 4, pero tu puente le cierra el paso: pierde la jugada.',
      'tut_sixes_intro': 'Ojo con los 6: el TERCER 6 seguido es castigo. Mira lo que le pasa al azul.',
      'tut_sixes_rival': 'El azul tira…',
      'tut_sixes_done': '¡Tercer 6 seguido! Una de sus fichas vuelve a casa y pierde el turno.',
      'tut_exact_intro': 'Para entrar a la META necesitas el número EXACTO. A tu ficha de la 98 le faltan 2, y a la de la 99, 1.',
      'tut_exact_roll_over': 'Toca tu dado.',
      'tut_exact_over': 'Sacaste 6: te pasas de la meta, así que no puedes mover. Pero el 6 te da otro tiro.',
      'tut_exact_roll': 'Necesitas un 2 para la ficha de la 98. ¡Tira!',
      'tut_exact_move': '¡Un 2 exacto! Mete tu ficha en la meta.',
      'tut_finish_bonus': '¡Ficha en la meta! Meter una ficha también te da un tiro extra.',
      'tut_exact_last': 'Ahora un 1 para la última. ¡Tira!',
      'tut_done_title': '¡Listo, ya sabes jugar!',
      'tut_done_body': 'Sales con cualquier número, el 6 repite, capturar da un tiro extra, los puentes bloquean, el tercer 6 castiga y a la meta se entra con el número exacto.',
      'tut_play_ai': 'Jugar mi primera partida contra la IA',
      'tut_menu': 'Ir al menú',
      'tut_reward': '+{xp} XP por aprender a jugar',
      // Privacy & Account
      'privacy_policy': 'Política de Privacidad',
      'credits': 'Créditos',
      'delete_account': 'Eliminar cuenta',
      'delete_account_confirm': '¿Estás seguro de que quieres eliminar tu cuenta permanentemente? Esta acción no se puede deshacer.',
      'delete_account_success': 'Tu cuenta y datos han sido eliminados permanentemente.',
      'confirm': 'Confirmar',
      'cancel': 'Cancelar',
      // Moderation
      'report_player': 'Reportar jugador',
      'block_player': 'Bloquear jugador',
      'unblock_player': 'Desbloquear jugador',
      'report_reason': 'Selecciona el motivo del reporte',
      'offensive_language': 'Lenguaje ofensivo',
      'inappropriate_name': 'Nombre inapropiado',
      'cheating': 'Trampas / Hackeo',
      'other': 'Otro',
      'report_sent': 'Reporte enviado con éxito',
      'player_blocked': 'Jugador bloqueado',
      'player_unblocked': 'Jugador desbloqueado',
      // UX & Settings
      'sound': 'Sonido',
      'vibration': 'Vibración',
      'game_speed': 'Velocidad de Juego',
      'speed_normal': 'Normal',
      'speed_fast': 'Rápida',
      // Game Events
      'penalty_three_sixes': '¡Tres 6 seguidos! Penalización para {name}',
      'extra_turn': '¡Turno extra para {name}!',
      'player_cant_move': '{name} no puede mover',
      'token_finished_bonus': '¡{name} metió una ficha! +1 Turno',
      'bad_luck_home': '¡Mala suerte! {name} vuelve a casa',
      'flying_to_cell': '{name} vuela a la casilla {cell}',
      'loses_turn': '¡{name} pierde un turno!',
      'roll_again': '¡Tira de nuevo {name}!',
      'captured_player': '¡{name} capturó a {other}! +1 Turno',
      'skip_turn_msg': '{name} pierde este turno',
      'cell_action_go_to_start': '¡Trampa! {name} vuelve al inicio',
      'cell_action_roll_again': '¡Casilla especial! {name} vuelve a tirar',
      'cell_action_skip_turn': '¡Penalización! {name} pierde el turno',
      'cell_action_move_to': '{name} vuela a la casilla {cell}',
      // Game Exit
      'exit_game_title': '¿Salir al menú?',
      'exit_game_content': 'Tu partida se guardará automáticamente. Podrás continuarla más tarde desde el menú principal.',
      'exit_online_content': 'Salir cuenta como rendirse: derrota registrada, sin XP. Los demás jugadores continuarán.',
      'player_left_match': '{name} abandonó la partida',
      'stay': 'Quedarse',
      'leave': 'Salir',
      'player_n_name': 'Nombre {player}',
      'ai_player_name': 'IA {n}',
      'ai_name_1': 'Bot Pro 🤖',
      'ai_name_2': 'Turbo ⚡',
      'ai_name_3': 'Dado 🎲',
      'ai_name_4': 'Súper 🚀',
      'ai_name_5': 'Muro 🛡️',
      'ai_name_6': 'Flash 🏃',
      'continue_game': 'Continuar Partida',
      'continue_game_subtitle': 'Sigue donde lo dejaste',
      'pending_game_title': 'Partida Pendiente',
      'pending_game_message': 'Tienes una partida pendiente. ¿Qué deseas hacer?',
      'start_new_game': 'Nueva Partida',
      'delete_game': 'Borrar Juego',
      'victory_automatic_title': '🏆 ¡Victoria Automática!',
      'victory_automatic_subtitle': 'Los demás jugadores abandonaron la partida. ¡Eres el ganador por defecto!',
      'delete_game_confirm': '¿Estás seguro de que quieres borrar la partida guardada? Esta acción no se puede deshacer.',
      // Lobby transitions
      'match_found_title': '¡PARTIDA ENCONTRADA!',
      'preparing_board': 'Preparando el tablero...',
      // Quick Chat
      'quick_msg_good_game': '¡Buena jugada!',
      'quick_msg_oops': '¡Rayos!',
      'quick_msg_hello': '¡Hola!',
      'quick_msg_play_fast': '¡Juega rápido!',
      // Google Auth
      'sign_in_required': 'Inicia sesión para jugar en línea',
      'lobby_timeout': 'La sala expiró sin completarse. Crea o busca otra partida.',
      'update_required_title': 'Actualización necesaria',
      'update_required_body': 'Esta versión ya no puede jugar en línea. Actualiza la app para seguir jugando.',
      'update_required_action': 'Actualizar',
      'update_required_later': 'Más tarde',
      'match_closed': 'La partida se cerró por superar el tiempo máximo.',
      'player_surrendered_msg': '{name} se rindió; la IA toma su lugar',
      'sign_in_required_content': 'Necesitas una cuenta de Google para el modo en línea.',
      'session_conflict_title': 'Sesión activa en otro dispositivo',
      'session_conflict_content': 'Tu cuenta ya está conectada desde otro dispositivo. Cierra esa sesión antes de continuar aquí.',
      'sign_in_google': 'Iniciar sesión con Google',
      'sign_out_google': 'Cerrar sesión de Google',
      'syncing': 'Sincronizando...',
      'offline_xp_pending': 'XP Offline Pendiente',
      // Auth error messages
      'auth_signout_confirm_title': '¿Cerrar sesión?',
      'auth_signout_confirm_body': '¿Estás seguro de que quieres cerrar sesión de tu cuenta de Google?',
      'auth_signout_confirm_btn': 'Cerrar sesión',
      'auth_no_internet_signin': 'Se requiere conexión a Internet para iniciar sesión.',
      'auth_signin_failed': 'Error al iniciar sesión. Inténtalo de nuevo.',
      'auth_no_internet_signout': 'Se requiere conexión a Internet para cerrar sesión.',
      'auth_no_internet_delete': 'Se requiere conexión a Internet para eliminar tu cuenta. Conéctate e inténtalo de nuevo.',
      'auth_delete_failed': 'No se pudo eliminar la cuenta. Tu cuenta no ha sido modificada. Inténtalo de nuevo.',
      'auth_delete_wrong_account': 'Para confirmar, elige la misma cuenta de Google con la que entraste.',
      'auth_delete_title': 'Error al Eliminar Cuenta',
      'auth_delete_loading': 'Eliminando cuenta...',
      // Onboarding
      'welcome_to_parche': '¡Bienvenido a Parché!',
      'create_your_profile': 'Crea tu perfil',
      'continue_with_google': 'Continuar con Google',
      'play_as_guest': 'Jugar como Invitado',
      'privacy_policy_agree_prefix': 'Al continuar, aceptas nuestra ',
      'step_n_of_3': 'Paso {n} de 3',
      'confirm_your_name': 'Confirma tu nombre',
      // Difficulty
      'difficulty': 'Dificultad',
      'difficulty_easy': 'Fácil',
      'difficulty_medium': 'Normal',
      'difficulty_hard': 'Difícil',
      'difficulty_easy_desc': '50 casillas · Sin penalizaciones · ×0.5 XP',
      'difficulty_medium_desc': '100 casillas · Clásico · ×1.0 XP',
      'difficulty_hard_desc': '100 casillas · Más penalizaciones · ×1.5 XP',
      'difficulty_last_place_no_xp': '4° lugar no recibe XP',
      // Statistics
      'stats_title': 'ESTADÍSTICAS',
      'stats_matches_played': 'Partidas jugadas',
      'stats_wins': 'Victorias',
      'stats_win_rate': 'Tasa de victoria',
      'stats_no_data': 'Juega tu primera partida\npara ver tus estadísticas.',
      // Daily mastery
      'daily_mastery_title': '🏆 ¡Dominio Diario Alcanzado!',
      'daily_mastery_content': 'Has alcanzado el máximo de XP de práctica por hoy. ¡Lleva tus habilidades al Modo Online para seguir subiendo de nivel y escalar en los rankings globales!',
      'daily_mastery_capped_title': '⭐ ¡XP {mode} Agotada!',
      'daily_mastery_capped_content': 'Has alcanzado el límite de XP en modo {mode} por hoy. ¡Todavía puedes ganar XP en {available}!',
      // Guest XP migration dialog
      'migration_title': '¡Tienes Progreso Sin Conectar!',
      'migration_content': 'Tu cuenta de Google está en Nivel {cloudLevel}, pero jugando sin conexión llegaste al Nivel {guestLevel}. ¿Qué progreso quieres conservar?',
      'migration_keep': 'Progreso sin conexión (Nivel {guestLevel})',
      'migration_fresh': 'Mi cuenta (Nivel {cloudLevel})',
      'daily_mastery_play_fun': 'Jugar por diversión',
      'daily_mastery_go_online': '¡Ir en línea!',
      // Level tooltip
      'level_max': '¡Nivel Máximo alcanzado!',
      'new_rank_reached': '¡NUEVO RANGO ALCANZADO!',
      'level_xp_progress': '{current} / {required} XP para Nivel {next}',
      'level_rank_missing': '\nTe faltan {missing} XP para ser {rank}',
      // Privacy Policy Content
      'privacy_policy_title': 'POLÍTICA DE PRIVACIDAD',
      'privacy_last_updated': 'Última actualización: 13 de mayo de 2026',
      'privacy_intro': 'En Parché, nos tomamos muy en serio la protección de tus datos personales. '
          'Esta Política de Privacidad explica qué información recopilamos, cómo la usamos y cómo puedes controlarla.',
      'privacy_s1_title': '1. Información que Recopilamos',
      'privacy_s1_body': 'Recopilamos los siguientes datos para ofrecerte la experiencia de juego:\n'
          '• Cuenta Google: nombre, correo electrónico y foto de perfil al iniciar sesión con Google.\n'
          '• Identificador de dispositivo: UUID generado para identificarte en partidas.\n'
          '• Datos de juego: XP, nivel, victorias, estadísticas y nombre de usuario.\n'
          '• Mensajes de chat: los mensajes que envías durante las partidas.',
      'privacy_s2_title': '2. Uso de la Información',
      'privacy_s2_body': 'Utilizamos tus datos exclusivamente para:\n'
          '• Gestionar tu cuenta y progresión en el juego.\n'
          '• Habilitar el juego multijugador en tiempo real.\n'
          '• Sincronizar tu progreso entre dispositivos.\n'
          '• Mostrar tu nombre y estadísticas en el tablero y clasificaciones.\n'
          '• Moderar contenido y garantizar un entorno de juego justo.',
      'privacy_s3_title': '3. Servicios de Terceros',
      'privacy_s3_body': 'La aplicación usa los siguientes servicios de terceros:\n'
          '• Google Firebase (Autenticación, Firestore, Cloud) — de Google LLC.\n'
          '• Google Sign-In — para autenticación segura de cuentas.\n'
          'Consulta la política de privacidad de Google en policies.google.com.',
      'privacy_s4_title': '4. Compartición de Datos',
      'privacy_s4_body': 'No vendemos ni compartimos tus datos con terceros con fines publicitarios o comerciales. '
          'Los datos solo se comparten con los servicios mencionados arriba, necesarios para el funcionamiento de la app.',
      'privacy_s5_title': '5. Retención de Datos',
      'privacy_s5_body': 'Conservamos tus datos mientras tu cuenta permanezca activa. '
          'Al eliminar tu cuenta, todos tus datos (perfil, progreso, historial) se borran permanentemente en un plazo de 30 días.',
      'privacy_s6_title': '6. Tus Derechos y Eliminación de Datos',
      'privacy_s6_body': 'Tienes derecho a acceder, corregir y eliminar tus datos personales en cualquier momento.\n'
          '• Eliminación desde la App: Ve a Ajustes → "Eliminar cuenta".\n'
          '• Por correo: jorgeluisalmanzar@gmail.com — Asunto: "Solicitud de eliminación de datos".\n'
          'Cumplimos con las políticas de seguridad de datos de Google Play y App Store.',
      'privacy_s7_title': '7. Privacidad de Menores',
      'privacy_s7_body': 'El modo sin conexión de Parché está disponible para usuarios de todas las edades y no recopila ningún dato personal.\n'
          'Las funciones en línea (inicio de sesión con Google, multijugador, sincronización en la nube) requieren tener 13 años o más, '
          'conforme a los Términos de Servicio de Google y la normativa COPPA.\n'
          'No recopilamos intencionalmente datos personales de menores de 13 años a través de los servicios en línea. '
          'Si crees que un menor ha proporcionado datos, contáctanos para eliminarlos.',
      'privacy_s8_title': '8. Seguridad',
      'privacy_s8_body': 'Toda la comunicación usa cifrado SSL/TLS. '
          'Los datos se almacenan en Google Firebase, que cumple con los estándares ISO 27001 y SOC 2.',
      'privacy_s9_title': '9. Cambios en Esta Política',
      'privacy_s9_body': 'Podemos actualizar esta política periódicamente. '
          'Te notificaremos de cambios importantes a través de la aplicación.',
      'privacy_s10_title': '10. Contacto',
      'privacy_s10_body': 'Para preguntas o para ejercer tus derechos:\nCorreo: jorgeluisalmanzar@gmail.com',
      'privacy_view_web': 'Ver versión web completa',
    },
    Language.en: {
      'waiting_players': 'Waiting for Players...',
      'room_code': 'Code',
      'code_copied': 'Code copied!',
      'online': '● ONLINE',
      'offline': '○ OFFLINE',
      'reconnecting': '⏳ RECONNECTING...',
      'chat_unavailable': 'Chat available soon',
      'chat_input_hint': 'Type a message...',
      'podium_title': '🏆 FINAL PODIUM 🏆',
      'back_to_menu': 'Back to Menu',
      'connection_lost': 'Connection Lost',
      'server_connection_lost': 'Connection to server has been lost.',
      'exit': 'Exit',
      'select_mode': 'Select game mode',
      'offline_mode': 'Offline',
      'offline_subtitle': 'Play near you',
      'online_mode': 'Online',
      'online_subtitle': 'Play remotely',
      'settings': 'Settings',
      'language': 'Language',
      'spanish': 'Spanish',
      'english': 'English',
      'close': 'Close',
      'player': 'Player',
      'select_player_count': 'Select number of players',
      'play_vs_ai': 'Play vs AI',
      'ai_info_content': 'By enabling this option, empty slots will be filled by machine-controlled players.',
      'start_game': 'START GAME',
      'back': '← Back',
      'players_count': 'players',
      'multiplayer_online': 'Online Multiplayer',
      'quick_match': '⚡ QUICK MATCH',
      'quick_match_subtitle': 'Search for opponents now',
      'play_with_friends': 'Play with Friends',
      'play_with_friends_subtitle': 'Create or join rooms',
      'create_new_room': '➕ CREATE NEW ROOM',
      'private_code': 'PRIVATE CODE',
      'join_by_code': 'JOIN BY CODE',
      'leave_room': 'LEAVE ROOM',
      'waiting_room': 'WAITING ROOM',
      'waiting_room_subtitle': 'The game will start when the room is full.',
      'ai_fill_offer': 'Nobody else has joined yet.',
      'ai_fill_button': 'PLAY NOW AGAINST AI',
      'ai_fill_xp_hint': 'Empty seats are filled with AI. This match gives half the XP.',
      'name_hint': 'YOUR NAME',
      'enter_name_title': 'What is your name?',
      'rejoin_match': 'REJOIN MATCH',
      'no_matches_found': 'No matches available',
      'no_matches_content': 'There are no public rooms waiting at this time.',
      'play_offline': 'Play Offline',
      'create_my_room': 'Create my Room',
      'configure_room': 'Configure new room',
      'public_room': 'Public Room',
      'public_room_subtitle': 'Allow strangers to join',
      'search_quick_match': 'Search Quick Match',
      'enter_name_error': 'Enter your name',
      'all_names_mandatory': 'All name fields must be filled',
      'name_code_error': 'Name and code are required',
      'your_turn': 'YOUR TURN',
      // Board Labels
      'board_start': 'Start',
      'board_finish': 'Finish',
      'board_go_to_start': 'START',
      'board_move_to': 'To {target}',
      'board_skip_turn': 'Skip\nturn',
      'board_extra_turn': 'Extra\nturn',
      // Tutorial
      'tutorial': 'Tutorial',
      'tutorial_title': 'New to Parché?',
      'tutorial_content': 'Do you want to see a quick tutorial to learn how to play?',
      'tutorial_start': 'Yes, learn now',
      'tutorial_skip': 'No, I already know how',
      'tutorial_exit_title': 'Finish Tutorial',
      'tutorial_exit_content': 'Are you sure you want to leave the tutorial? All current progress will be lost.',
      'tut_progress': 'Step {n} of {total}',
      'tut_you_name': 'You',
      'tut_rival_name': 'Blue',
      'tut_skip': 'Skip',
      'tut_next': 'Next',
      'tut_your_move': 'Your turn',
      'tut_watch': 'Watch…',
      'tut_goal': 'Welcome! The first to get both tokens HOME, the last cell, wins. Let me show you in a minute.',
      'tut_leave_roll': 'Tap your die to roll.',
      'tut_leave_move': 'Here you leave home with ANY number. Tap one of your tokens to bring it out.',
      'tut_six_roll': 'Roll again.',
      'tut_six_move': 'A 6! Move a token… and since you rolled a 6, you roll again afterwards.',
      'tut_six_again': 'The 6 gave you another roll. Roll again!',
      'tut_move_any': 'Tap a token to move it.',
      'tut_roll': 'Tap your die to roll.',
      'tut_capture_intro': 'See the blue token 3 cells ahead of yours? Land exactly on its cell and you capture it.',
      'tut_capture_move': 'A 3! Move your token on the track onto the blue one.',
      'tut_capture_done': 'Captured! The blue token went back home and you earned an extra roll.',
      'tut_cells_intro': 'Orange cells hold surprises. Let\'s land on one.',
      'tut_cells_roll': 'Take your token to the "Extra turn" cell. Tap your die.',
      'tut_cells_move': 'Tap your token on the track.',
      'tut_cell_extra': '"Extra turn": you roll again. That\'s why it\'s still your turn!',
      'tut_cell_skip': '"Skip turn": land here and you miss your next turn.',
      'tut_cell_start': '"Back to start": your token goes home. Watch out for this one!',
      'tut_cell_jump': '"Go to": sends you to another cell. This one lifts you from 24 to 63… but others drop you back.',
      'tut_bridge_intro': 'Two of your tokens on the same cell make a BRIDGE. Let\'s build one.',
      'tut_bridge_move': 'Move your back token next to the other one.',
      'tut_bridge_done': 'A bridge! Nobody can pass or land on that cell… not even you.',
      'tut_bridge_rival': 'Blue\'s turn…',
      'tut_bridge_blocked': 'Blue rolled a 4, but your bridge blocks the way: the roll is lost.',
      'tut_sixes_intro': 'Careful with 6s: the THIRD 6 in a row is a penalty. Watch what happens to blue.',
      'tut_sixes_rival': 'Blue rolls…',
      'tut_sixes_done': 'Third 6 in a row! One of its tokens goes back home and the turn is over.',
      'tut_exact_intro': 'To get HOME you need the EXACT number. Your token on 98 needs 2, the one on 99 needs 1.',
      'tut_exact_roll_over': 'Tap your die.',
      'tut_exact_over': 'You rolled a 6: too far for home, so you can\'t move. But the 6 gives you another roll.',
      'tut_exact_roll': 'You need a 2 for the token on 98. Roll!',
      'tut_exact_move': 'An exact 2! Move your token home.',
      'tut_finish_bonus': 'Token home! Getting a token home also earns an extra roll.',
      'tut_exact_last': 'Now a 1 for the last one. Roll!',
      'tut_done_title': 'Done, you know how to play!',
      'tut_done_body': 'Leave home with any number, a 6 rolls again, captures earn a roll, bridges block, the third 6 is a penalty, and home takes the exact number.',
      'tut_play_ai': 'Play my first match against the AI',
      'tut_menu': 'Go to menu',
      'tut_reward': '+{xp} XP for learning to play',
      // Privacy & Account
      'privacy_policy': 'Privacy Policy',
      'credits': 'Credits',
      'delete_account': 'Delete account',
      'delete_account_confirm': 'Are you sure you want to permanently delete your account? This action cannot be undone.',
      'delete_account_success': 'Your account and data have been permanently deleted.',
      'confirm': 'Confirm',
      'cancel': 'Cancel',
      // Moderation
      'report_player': 'Report player',
      'block_player': 'Block player',
      'unblock_player': 'Unblock player',
      'report_reason': 'Select report reason',
      'offensive_language': 'Offensive language',
      'inappropriate_name': 'Inappropriate name',
      'cheating': 'Cheating / Hacking',
      'other': 'Other',
      'report_sent': 'Report sent successfully',
      'player_blocked': 'Player blocked',
      'player_unblocked': 'Player unblocked',
      // UX & Settings
      'sound': 'Sound',
      'vibration': 'Vibration',
      'game_speed': 'Game Speed',
      'speed_normal': 'Normal',
      'speed_fast': 'Fast',
      // Game Events
      'penalty_three_sixes': 'Three 6s in a row! Penalty for {name}',
      'extra_turn': 'Extra turn for {name}!',
      'player_cant_move': '{name} cannot move',
      'token_finished_bonus': '{name} scored a token! +1 Turn',
      'bad_luck_home': 'Bad luck! {name} goes back home',
      'flying_to_cell': '{name} flies to cell {cell}',
      'loses_turn': '{name} loses a turn!',
      'roll_again': 'Roll again {name}!',
      'captured_player': '{name} captured {other}! +1 Turn',
      'skip_turn_msg': '{name} skips this turn',
      'cell_action_go_to_start': 'Trap! {name} goes back to start',
      'cell_action_roll_again': 'Special cell! {name} rolls again',
      'cell_action_skip_turn': 'Penalty! {name} loses a turn',
      'cell_action_move_to': '{name} flies to cell {cell}',
      // Game Exit
      'exit_game_title': 'Exit to menu?',
      'exit_game_content': 'Your game will be automatically saved. You can continue later from the main menu.',
      'exit_online_content': 'Leaving counts as a surrender: loss recorded, no XP awarded. Other players will continue.',
      'player_left_match': '{name} left the match',
      'stay': 'Stay',
      'leave': 'Leave',
      'player_n_name': '{player} Name',
      'ai_player_name': 'AI {n}',
      'ai_name_1': 'Bot Pro 🤖',
      'ai_name_2': 'Turbo ⚡',
      'ai_name_3': 'Dice 🎲',
      'ai_name_4': 'Super 🚀',
      'ai_name_5': 'Wall 🛡️',
      'ai_name_6': 'Flash 🏃',
      'continue_game': 'Continue Game',
      'continue_game_subtitle': 'Pick up where you left off',
      'pending_game_title': 'Pending Game',
      'pending_game_message': 'You have a pending game. What do you want to do?',
      'start_new_game': 'New Game',
      'delete_game': 'Delete Game',
      'victory_automatic_title': '🏆 Automatic Victory!',
      'victory_automatic_subtitle': 'Other players left the match. You are the winner by default!',
      'delete_game_confirm': 'Are you sure you want to delete the saved game? This action cannot be undone.',
      // Lobby transitions
      'match_found_title': 'MATCH FOUND!',
      'preparing_board': 'Preparing the board...',
      // Quick Chat
      'quick_msg_good_game': 'Good game!',
      'quick_msg_oops': 'Oops!',
      'quick_msg_hello': 'Hello!',
      'quick_msg_play_fast': 'Play fast!',
      // Google Auth
      'sign_in_required': 'Sign in to play online',
      'lobby_timeout': 'The room expired before filling up. Create or find another match.',
      'update_required_title': 'Update required',
      'update_required_body': 'This version can no longer play online. Update the app to keep playing.',
      'update_required_action': 'Update',
      'update_required_later': 'Later',
      'match_closed': 'The match was closed for exceeding the maximum duration.',
      'player_surrendered_msg': '{name} surrendered; the AI takes their seat',
      'sign_in_required_content': 'You need a Google account to access online mode.',
      'session_conflict_title': 'Active session on another device',
      'session_conflict_content': 'Your account is already connected from another device. Close that session before continuing here.',
      'sign_in_google': 'Sign in with Google',
      'sign_out_google': 'Sign out of Google',
      'syncing': 'Syncing...',
      'offline_xp_pending': 'Offline XP Pending',
      // Auth error messages
      'auth_signout_confirm_title': 'Sign out?',
      'auth_signout_confirm_body': 'Are you sure you want to sign out of your Google account?',
      'auth_signout_confirm_btn': 'Sign out',
      'auth_no_internet_signin': 'Internet connection is required to sign in.',
      'auth_signin_failed': 'Sign-in failed. Please try again.',
      'auth_no_internet_signout': 'Internet connection is required to sign out.',
      'auth_no_internet_delete': 'Internet connection is required to delete your account. Please connect and try again.',
      'auth_delete_failed': 'Failed to delete account. Your account has not been changed. Please try again.',
      'auth_delete_wrong_account': 'To confirm, choose the same Google account you signed in with.',
      'auth_delete_title': 'Account Deletion Failed',
      'auth_delete_loading': 'Deleting account...',
      // Onboarding
      'welcome_to_parche': 'Welcome to Parché!',
      'create_your_profile': 'Create your profile',
      'continue_with_google': 'Continue with Google',
      'play_as_guest': 'Play as Guest',
      'privacy_policy_agree_prefix': 'By continuing, you agree to our ',
      'step_n_of_3': 'Step {n} of 3',
      'confirm_your_name': 'Confirm your name',
      // Difficulty
      'difficulty': 'Difficulty',
      'difficulty_easy': 'Easy',
      'difficulty_medium': 'Normal',
      'difficulty_hard': 'Hard',
      'difficulty_easy_desc': '50 cells · No penalties · ×0.5 XP',
      'difficulty_medium_desc': '100 cells · Classic · ×1.0 XP',
      'difficulty_hard_desc': '100 cells · More penalties · ×1.5 XP',
      'difficulty_last_place_no_xp': '4th place earns no XP',
      // Statistics
      'stats_title': 'STATISTICS',
      'stats_matches_played': 'Matches played',
      'stats_wins': 'Wins',
      'stats_win_rate': 'Win rate',
      'stats_no_data': 'Play your first match\nto see your statistics.',
      // Daily mastery
      'daily_mastery_title': '🏆 Daily Mastery Reached!',
      'daily_mastery_content': 'You\'ve maximized your practice XP for today. Take your skills to the Online Arena to continue leveling up and climbing the global ranks!',
      'daily_mastery_capped_title': '⭐ {mode} XP Maxed!',
      'daily_mastery_capped_content': 'You\'ve reached today\'s {mode} XP limit. You can still earn XP on {available}!',
      // Guest XP migration dialog
      'migration_title': 'You Have Offline Progress!',
      'migration_content': 'Your Google account is at Level {cloudLevel}, but playing offline you reached Level {guestLevel}. Which progress do you want to keep?',
      'migration_keep': 'Offline Progress (Level {guestLevel})',
      'migration_fresh': 'My Account (Level {cloudLevel})',
      'daily_mastery_play_fun': 'Play for fun',
      'daily_mastery_go_online': 'Go Online!',
      // Level tooltip
      'level_max': 'Maximum Level reached!',
      'new_rank_reached': 'NEW RANK REACHED!',
      'level_xp_progress': '{current} / {required} XP for Level {next}',
      'level_rank_missing': '\n{missing} XP left to become {rank}',
      // Privacy Policy Content
      'privacy_policy_title': 'PRIVACY POLICY',
      'privacy_last_updated': 'Last updated: May 13, 2026',
      'privacy_intro': 'At Parché, we take the protection of your personal data seriously. '
          'This Privacy Policy explains what information we collect, how we use it, and how you can control it.',
      'privacy_s1_title': '1. Information We Collect',
      'privacy_s1_body': 'We collect the following data to provide you with the gaming experience:\n'
          '• Google Account: name, email address, and profile photo when you sign in with Google.\n'
          '• Device identifier: a UUID generated to identify you in matches.\n'
          '• Game data: XP, level, wins, match statistics, and chosen username.\n'
          '• Chat messages: messages you send during matches.',
      'privacy_s2_title': '2. How We Use Your Information',
      'privacy_s2_body': 'We use your data exclusively to:\n'
          '• Manage your account and in-game progression.\n'
          '• Enable real-time multiplayer gaming.\n'
          '• Sync your progress across devices.\n'
          '• Display your name and stats on the board and leaderboards.\n'
          '• Moderate content and ensure a fair gaming environment.',
      'privacy_s3_title': '3. Third-Party Services',
      'privacy_s3_body': 'The app uses the following third-party services:\n'
          '• Google Firebase (Authentication, Firestore, Cloud) — by Google LLC.\n'
          '• Google Sign-In — for secure account authentication.\n'
          "See Google's Privacy Policy at policies.google.com.",
      'privacy_s4_title': '4. Data Sharing',
      'privacy_s4_body': 'We do not sell or share your personal data with third parties for advertising or commercial purposes. '
          'Data is only shared with the third-party services listed above, required for the app to function.',
      'privacy_s5_title': '5. Data Retention',
      'privacy_s5_body': 'We retain your data for as long as your account remains active. '
          'When you delete your account, all your data (profile, progress, history) is permanently deleted within 30 days.',
      'privacy_s6_title': '6. Your Rights & Data Deletion',
      'privacy_s6_body': 'You have the right to access, correct, and delete your personal data at any time.\n'
          '• In-App Deletion: Go to Settings → "Delete account".\n'
          '• Email Request: jorgeluisalmanzar@gmail.com — Subject: "Data Deletion Request".\n'
          'We comply with Google Play and App Store data safety policies.',
      'privacy_s7_title': "7. Children's Privacy",
      'privacy_s7_body': "Parché's offline mode is available to users of all ages and collects no personal data.\n"
          'Online features (Google Sign-In, multiplayer, cloud sync) require users to be 13 or older, '
          "in accordance with Google's Terms of Service and COPPA regulations.\n"
          'We do not knowingly collect personal data from children under 13 through our online services. '
          'If you believe a child has provided data, contact us to have it removed.',
      'privacy_s8_title': '8. Security',
      'privacy_s8_body': 'All communication uses SSL/TLS encryption. '
          'Data is securely stored in Google Firebase, which complies with ISO 27001 and SOC 2 security standards.',
      'privacy_s9_title': '9. Changes to This Policy',
      'privacy_s9_body': 'We may update this Privacy Policy periodically. '
          'We will notify you of significant changes through the app.',
      'privacy_s10_title': '10. Contact Us',
      'privacy_s10_body': 'For questions or to exercise your rights:\nEmail: jorgeluisalmanzar@gmail.com',
      'privacy_view_web': 'View full web version',
    },
  };
}

extension LanguageExtension on BuildContext {
  String translate(String key, {Map<String, String>? args, bool listen = true}) {
    return (listen ? watch<LanguageProvider>() : read<LanguageProvider>())
        .translate(key, args: args);
  }
}
