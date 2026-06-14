@tool
extends EditorPlugin

const BridgeServer = preload("res://addons/claude_bridge/bridge_server.gd")
const BridgeDock = preload("res://addons/claude_bridge/dock.gd")
const AgentLink = preload("res://addons/claude_bridge/agent_link.gd")
const CaptureLogger = preload("res://addons/claude_bridge/capture_logger.gd")
const EditorDebug = preload("res://addons/claude_bridge/commands/editor_debug.gd")
const ParticlesCmds = preload("res://addons/claude_bridge/commands/particles.gd")
const AudioCmds = preload("res://addons/claude_bridge/commands/audio.gd")
const AnimationTreeCmds = preload("res://addons/claude_bridge/commands/animation_tree.gd")
const ThemeCmds = preload("res://addons/claude_bridge/commands/theme.gd")

var server: BridgeServer
var dock: Control
var agent_link
var editor_logger


func _enter_tree() -> void:
	editor_logger = CaptureLogger.new()
	OS.add_logger(editor_logger)

	agent_link = AgentLink.new()
	agent_link.start(9081)

	server = BridgeServer.new()
	server.agent_link = agent_link
	server.modules.append(EditorDebug.new(editor_logger, agent_link))
	server.modules.append(ParticlesCmds.new())
	server.modules.append(AudioCmds.new())
	server.modules.append(AnimationTreeCmds.new())
	server.modules.append(ThemeCmds.new())
	agent_link.log_message.connect(func(text, kind): server.log_message.emit(text, kind))

	dock = BridgeDock.new()
	dock.name = "Claude Bridge"
	dock.setup(server)
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, dock)

	# Arranca automáticamente al activar el plugin
	server.start(dock.get_saved_port())


func _exit_tree() -> void:
	if editor_logger:
		OS.remove_logger(editor_logger)
		editor_logger = null
	if agent_link:
		agent_link.stop()
		agent_link = null
	if server:
		server.stop()
		server = null
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null


func _enable_plugin() -> void:
	add_autoload_singleton("ClaudeRuntime", "res://addons/claude_bridge/runtime_agent.gd")


func _disable_plugin() -> void:
	remove_autoload_singleton("ClaudeRuntime")


func _process(_delta: float) -> void:
	if server:
		server.poll()
	if agent_link:
		agent_link.poll()
