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

  static const Map<Language, Map<String, String>> _translations = {
    Language.es: {
      'waiting_players': 'Esperando Jugadores...',
      'room_code': 'Código',
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
      'tutorial_step_dice_1': 'Toca el dado para lanzar y salir a la pista.',
      'tutorial_step_move_1': 'Toca tu ficha para moverla al tablero.',
      'tutorial_step_transition_blue': '¡Bien hecho! Ahora es el turno del oponente. Vamos a ver cómo capturar.',
      'tutorial_step_dice_2': 'El oponente lanza su dado...',
      'tutorial_step_capture': 'El oponente mueve su ficha y captura la tuya mandándola a casa.',
      'tutorial_step_extra_explanation': '¡Increíble! Al capturar, el oponente ganó un tiro adicional.',
      'tutorial_step_dice_3': '¡Mira! Los turnos extra permiten avanzar mucho más rápido.',
      'tutorial_step_six_info': 'Cuando sacas un 6, el jugador repite turno. Observa cómo el azul avanza de nuevo.',
      'tutorial_step_action_start': 'Casilla de mandar a inicio: Si caes aquí, vuelves al principio.',
      'tutorial_step_action_skip': 'Casilla de un turno sin jugar: Perderás tu próximo turno.',
      'tutorial_step_action_extra': 'Casilla de turno extra: ¡Genial! Podrás tirar el dado otra vez.',
      'tutorial_step_action_move': 'Casilla de mover a otra casilla: Te transportará a otra posición.',
      'tutorial_finish': 'El objetivo es llevar todas tus fichas a la meta (casilla fin) para ganar la partida.',
      'tutorial_continue_sub': 'Toca aquí para continuar...',
      'tutorial_finish_sub': 'Finalizar...',
      'tutorial_tap_dice_continue': 'toca el dado para continuar',
      'tutorial_tap_token_continue': 'toca una ficha para continuar',
      'tutorial_tip': '¡Tip Extra! Al llevar tu primera ficha a la meta obtienes un turno adicional para mover tu otra ficha.',
      'tutorial_exit_title': 'Terminar Tutorial',
      'tutorial_exit_content': '¿Estás seguro de que quieres abandonar el tutorial? Todo tu progreso actual se perderá.',
      // Privacy & Account
      'privacy_policy': 'Política de Privacidad',
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
      // Game Exit
      'exit_game_title': '¿Salir al menú?',
      'exit_game_content': 'Tu partida se guardará automáticamente. Podrás continuarla más tarde desde el menú principal.',
      'exit_online_content': 'Si sales de la partida, otros jugadores seguirán jugando. Podrás volver a entrar si la partida sigue activa.',
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
      'sign_in_required_content': 'Necesitas una cuenta de Google para el modo en línea.',
      'sign_in_google': 'Iniciar sesión con Google',
      'sign_out_google': 'Cerrar sesión de Google',
      'syncing': 'Sincronizando...',
      'offline_xp_pending': 'XP Offline Pendiente',
      // Onboarding
      'welcome_to_parche': '¡Bienvenido a Parché!',
      'create_your_profile': 'Crea tu perfil',
      'continue_with_google': 'Continuar con Google',
      'play_as_guest': 'Jugar como Invitado',
      'privacy_policy_agree_prefix': 'Al continuar, aceptas nuestra ',
      'step_n_of_3': 'Paso {n} de 3',
      'confirm_your_name': 'Confirma tu nombre',
      'xp_bonus_received': '+50 XP ¡Bonus de bienvenida!',
      // Difficulty
      'difficulty': 'Dificultad',
      'difficulty_easy': 'Fácil',
      'difficulty_medium': 'Normal',
      'difficulty_hard': 'Difícil',
      'difficulty_easy_desc': '50 casillas · Sin penalizaciones · ×0.5 XP',
      'difficulty_medium_desc': '100 casillas · Clásico · ×1.0 XP',
      'difficulty_hard_desc': '100 casillas · Más penalizaciones · ×1.5 XP',
      'difficulty_last_place_no_xp': '4° lugar no recibe XP',
    },
    Language.en: {
      'waiting_players': 'Waiting for Players...',
      'room_code': 'Code',
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
      'tutorial_step_dice_1': 'Tap the dice to roll and get on the track.',
      'tutorial_step_move_1': 'Tap your token to move it to the board.',
      'tutorial_step_transition_blue': 'Well done! Now it is the opponent\'s turn. Let\'s see how to capture.',
      'tutorial_step_dice_2': 'The opponent rolls its dice...',
      'tutorial_step_capture': 'The opponent moves its token and captures yours, sending it home.',
      'tutorial_step_extra_explanation': 'Amazing! By capturing, the opponent earned an additional roll.',
      'tutorial_step_dice_3': 'Look! Extra turns allow you to move much faster.',
      'tutorial_step_six_info': 'When you roll a 6, the player repeats their turn. Watch how the blue moves again.',
      'tutorial_step_action_start': 'Go to start cell: If you land here, you go back to the beginning.',
      'tutorial_step_action_skip': 'Skip turn cell: You will lose your next turn.',
      'tutorial_step_action_extra': 'Extra turn cell: Great! You can roll the dice again.',
      'tutorial_step_action_move': 'Move to cell: It will transport you to another position.',
      'tutorial_finish': 'The goal is to get all your tokens to the finish line (finish square) to win the game.',
      'tutorial_continue_sub': 'Tap here to continue...',
      'tutorial_finish_sub': 'Finish...',
      'tutorial_tap_dice_continue': 'tap the dice to continue',
      'tutorial_tap_token_continue': 'tap a token to continue',
      'tutorial_tip': 'Extra Tip! To move your other token, you get an extra turn when your first token reaches the meta.',
      'tutorial_exit_title': 'Finish Tutorial',
      'tutorial_exit_content': 'Are you sure you want to leave the tutorial? All current progress will be lost.',
      // Privacy & Account
      'privacy_policy': 'Privacy Policy',
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
      // Game Exit
      'exit_game_title': 'Exit to menu?',
      'exit_game_content': 'Your game will be automatically saved. You can continue later from the main menu.',
      'exit_online_content': 'If you leave the game, other players will continue playing. You can rejoin if the game is still active.',
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
      'sign_in_required_content': 'You need a Google account to access online mode.',
      'sign_in_google': 'Sign in with Google',
      'sign_out_google': 'Sign out of Google',
      'syncing': 'Syncing...',
      'offline_xp_pending': 'Offline XP Pending',
      // Onboarding
      'welcome_to_parche': 'Welcome to Parché!',
      'create_your_profile': 'Create your profile',
      'continue_with_google': 'Continue with Google',
      'play_as_guest': 'Play as Guest',
      'privacy_policy_agree_prefix': 'By continuing, you agree to our ',
      'step_n_of_3': 'Step {n} of 3',
      'confirm_your_name': 'Confirm your name',
      'xp_bonus_received': '+50 XP Welcome Bonus!',
      // Difficulty
      'difficulty': 'Difficulty',
      'difficulty_easy': 'Easy',
      'difficulty_medium': 'Normal',
      'difficulty_hard': 'Hard',
      'difficulty_easy_desc': '50 cells · No penalties · ×0.5 XP',
      'difficulty_medium_desc': '100 cells · Classic · ×1.0 XP',
      'difficulty_hard_desc': '100 cells · More penalties · ×1.5 XP',
      'difficulty_last_place_no_xp': '4th place earns no XP',
    },
  };
}

extension LanguageExtension on BuildContext {
  String translate(String key, {Map<String, String>? args, bool listen = true}) {
    return (listen ? watch<LanguageProvider>() : read<LanguageProvider>())
        .translate(key, args: args);
  }
}
