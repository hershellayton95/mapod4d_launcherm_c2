# tool

# class_name

# extends
extends Control

## A brief description of your script.
##
## A more detailed description of the script.
##
## @tutorial:			http://the/tutorial1/url.com
## @tutorial(Tutorial2): http://the/tutorial2/url.com


# ----- signals

# ----- enums


enum STATUS_LOCAL {
	WAIT = 0,
	
	UPDATER_DW_INFO_REQUESTED,
	
	SW_DW_INFO_REQUESTED,
	SW_DW_INFO_WAIT,
	SW_DW_BRICKS,
	SW_DW_BRICK_WAIT,
	SW_DW_COMPLETED,
	
	MT_DW_INFO_REQUESTED,
	MT_DW_COMPLETED,
	
	MERGE_AND_MOVE,
	MERGE_AND_MOVE_ALL_BRICKS,
	MERGE_AND_MOVE_SINGLE_BRICK,
	READ_AND_SAVE,
	READ_AND_SAVE_ALL_CHUNKS,
	READ_AND_SAVE_GROUP_OF_CHUNKS
}

enum OP_TYPE_LOCAL {
	NONE = 0,
	SW_DW,
	MT_DW,
}

# ----- constants
const MULTIVSVR = "https://sv001.mapod4d.it"
const MULTIVSVR_PORT = 80
const BUF_NAME = "buf_"
const CHUNKSIZE = 550000
const CHUNKSIZE_MULTI = 1000

# ----- exported variables

# ----- public variables

# ----- private variables

# ----- onready variables
@onready var http_sw_info_rq = $HTTPSWRequestInfo
@onready var http_sw_dw_rq = $HTTPSWRequestDownload
@onready var http_mt_info_rq = $HTTPSWRequestInfo
@onready var http_mt_dw_rq = $HTTPSWRequestDownload
@onready var software = $TabContainer/Software
@onready var metaverse = $TabContainer/Metaverse


# ----- optional built-in virtual _init method

# ----- built-in virtual _ready method
var _status = STATUS_LOCAL.WAIT
var _op_type:OP_TYPE_LOCAL = OP_TYPE_LOCAL.NONE

# commons
var _current_brick = 0
var _dw_name = null
var _download_file = null
var _info = null
var _url = null
var _dir = null
var _dest_file = null
var _input_file_data = null
var _input_file_data_read = false
var _brick_name = null
var _current_merging_brick = 0
var _current_chunk = 0
var _software_name = null
var _sysop = null
var _tmp_dir = null
var _destination = null
var _which = null

## sofware download vars
var _ext = null

## metaverse download vars
var _mapod4d_ver = null


# Called when the node enters the scene tree for the first time.
func _ready():
	http_sw_info_rq.request_completed.connect(
			_on_sw_dw_info_completed)
	http_sw_dw_rq.request_completed.connect(
			_on_sw_dw_brick_completed)

	software.download_software_requested.connect(
			_on_download_software_requested)
	metaverse.download_metaverse_requested.connect(
			_on_download_metaverse_requested)
	

# ----- remaining built-in virtual methods

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# status MACHINE
	if _status != STATUS_LOCAL.WAIT:
		match _status:
			STATUS_LOCAL.SW_DW_INFO_REQUESTED:
				sw_dw_info_requested()
			STATUS_LOCAL.SW_DW_INFO_WAIT:
				_child_update_download_info()
			STATUS_LOCAL.SW_DW_BRICKS:
				_sw_dw_bricks()
			STATUS_LOCAL.SW_DW_BRICK_WAIT:
				_child_update_download_info()
			STATUS_LOCAL.SW_DW_COMPLETED:
				_sw_dw_completed()

			STATUS_LOCAL.MT_DW_INFO_REQUESTED:
				mt_dw_info_requested()
			STATUS_LOCAL.MT_DW_COMPLETED:
				_mt_dw_completed()

			STATUS_LOCAL.MERGE_AND_MOVE:
				_merge_and_move()
			STATUS_LOCAL.MERGE_AND_MOVE_ALL_BRICKS:
				_merge_and_move_all_bricks()
			STATUS_LOCAL.MERGE_AND_MOVE_SINGLE_BRICK:
				_merge_and_move_single_brick()
			STATUS_LOCAL.READ_AND_SAVE:
				_read_and_save()
			STATUS_LOCAL.READ_AND_SAVE_ALL_CHUNKS:
				_read_and_save_all_chunks()
			STATUS_LOCAL.READ_AND_SAVE_GROUP_OF_CHUNKS:
				_read_and_save_group_of_chunks()

# ----- public methods

# ----- private methods

## reset info status
func _reset_info_and_wait():
	# commons
	_op_type = OP_TYPE_LOCAL.NONE
	_current_brick = 0
	_dw_name = null
	_download_file = null
	_info = null
	_url = null
	_dir = null
	if _dest_file != null:
		_dest_file.close()
		_dest_file = null
	if _input_file_data != null:
		_input_file_data.close()
		_input_file_data = null
	_input_file_data_read = false
	_brick_name = null
	_current_merging_brick = 0
	_current_chunk = 0
	_software_name = null
	_sysop = null
	_tmp_dir = null
	_destination = null
	_which = null

	## sofware download vars
	_ext = null

	## metaverse download vars
	_mapod4d_ver = null
	_set_status(STATUS_LOCAL.WAIT)


## send info to child
func _set_status(status):
	_status = status


## send info to child
func _child_update_msg(msg):
	if _which != null:
		_which.update_msg(msg)


## send info to child
func _child_update_merge_info(data):
	if _which != null:
		_which.update_merge_info(data)


func _child_update_download_info():
	if http_sw_dw_rq.get_http_client_status() == 7:
		var bs = http_sw_dw_rq.get_downloaded_bytes() 
		var db = http_sw_dw_rq.get_body_size()
		var perc = "%.2f" % 0
		if db > 0:
			perc = "%.2f" % ((float(bs) / float(db)) * 100.0)
			var data = {
				"bs": str(bs),
				"db": str(db),
				"perc": str(perc),
				"info": str(_info),
				"bricks": str(_info.bricks),
				"brick": _current_brick + 1,
			}
			if _which != null:
				_which.update_download_info(data)


func _mt_dw_completed():
	_child_update_msg("METAVERSE DOWNLOAD COMPLETED")
	_reset_info_and_wait()


## ENTRY 0 start metaverse download
func _on_download_metaverse_requested(
		software_name, mapod4d_ver, sysop, tmp_dir, destination, which):
	# https://sv001.mapod4d.it/api/multiverse/lastmetaverse/metaversetest/002000000002
	_op_type = OP_TYPE_LOCAL.MT_DW
	_software_name = software_name
	_mapod4d_ver = mapod4d_ver
	_sysop = sysop
	_tmp_dir = tmp_dir
	_destination = destination
	_which = which
	_set_status(STATUS_LOCAL.MT_DW_INFO_REQUESTED)


## download metaverse requested
func mt_dw_info_requested():
	_url = MULTIVSVR + "/api/multiverse/lastmetaverse/"
	_url += _software_name + "/" + _mapod4d_ver + "?format=json"
	print(_url)
	var headers = ["Content-Type: application/json"]
	_download_file = _tmp_dir + "/" + BUF_NAME
	http_sw_info_rq.request(_url, headers, HTTPClient.METHOD_GET)
	_set_status(STATUS_LOCAL.SW_DW_INFO_WAIT)


## SOFTWARE SECTION

func _sw_dw_completed():
	_child_update_msg("SOFTWARE DOWNLOAD COMPLETED")
	_reset_info_and_wait()


## ENTRY 0 start software download
func _on_download_software_requested(
		software_name, ext, sysop, tmp_dir, destination, which):
	_op_type = OP_TYPE_LOCAL.SW_DW
	_software_name = software_name
	_ext = ext
	_sysop = sysop
	_tmp_dir = tmp_dir
	_destination = destination
	_which = which
	_set_status(STATUS_LOCAL.SW_DW_INFO_REQUESTED)


## download software requested
func sw_dw_info_requested():
	_url = MULTIVSVR + "/api/software/"
	_url += _software_name + "/" + _sysop + "?format=json"
	print(_url)
	var headers = ["Content-Type: application/json"]
	_download_file = _tmp_dir + "/" + BUF_NAME
	http_sw_info_rq.request(_url, headers, HTTPClient.METHOD_GET)
	_set_status(STATUS_LOCAL.SW_DW_INFO_WAIT)


## info software download ended
func _on_sw_dw_info_completed(result, response_code, headers, body):
	print("progress")
	if result == HTTPRequest.RESULT_SUCCESS:
		var json = JSON.new()
		json.parse(body.get_string_from_utf8())
		print(body.get_string_from_utf8())
		print(json.get_data())
		_info = json.get_data()
		if _info != null:
			if 'detail' in _info:
				_child_update_msg("ERROR " + _info.detail)
				_reset_info_and_wait()
			else:
				print(_info.bricks)
				_dw_name = _info.link + "_"
				_current_brick = 0
				# SOLO DEBUG
				#_info.bricks = 1
				#_info.compressed = false
				# SOLO DEBUG FINE
				_set_status(STATUS_LOCAL.SW_DW_BRICKS)
		else:
			_child_update_msg("ERROR API NOT FOUND")
			_reset_info_and_wait()
	else:
		_child_update_msg("HTTPS REQUEST ERROR")
		_reset_info_and_wait()


## software download bricks X
func _sw_dw_bricks():
	print("brick " + str(_current_brick))
	if _current_brick >= _info.bricks:
		_child_update_msg("END DOWNLOAD " + _dw_name)
		_set_status(STATUS_LOCAL.MERGE_AND_MOVE)
	else:
		## download next brick
		http_sw_dw_rq.download_file = _download_file + str(_current_brick)
		print(http_sw_dw_rq.download_file)
		var url = _dw_name + str(_current_brick)
		print(url + " status:" + str(_status))
		http_sw_dw_rq.request(url)
		_set_status(STATUS_LOCAL.SW_DW_BRICK_WAIT)


## software download single brick X
func _on_sw_dw_brick_completed(result, response_code, headers, body):
	print(response_code)
	if result == HTTPRequest.RESULT_SUCCESS:
		if response_code == 200:
			_child_update_msg("BICK OK")
			_current_brick += 1
			_set_status(STATUS_LOCAL.SW_DW_BRICKS)
		else:
			## download error
			_child_update_msg("ERROR " + str(response_code))
			_reset_info_and_wait()
	else:
		## htpp error
		_child_update_msg("ERROR HTTP")
		_reset_info_and_wait()


## COMMON SECTION


func _merge_and_move():
	_dir = DirAccess.open(_tmp_dir)
	if _ext == null:
		_dest_file = FileAccess.open(
				_destination, FileAccess.WRITE)
	else:
		_dest_file = FileAccess.open(
				_destination + str(_ext), FileAccess.WRITE)
	_current_merging_brick = -1
	_set_status(STATUS_LOCAL.MERGE_AND_MOVE_ALL_BRICKS)


func _merge_and_move_all_bricks():
	print("_merge_and_move_all_blocks")
	_current_merging_brick += 1
	if _current_merging_brick >= _info.bricks:
		_dest_file.close()
		_child_update_msg("END MERGE AND MOVE")
		_set_status(STATUS_LOCAL.SW_DW_COMPLETED)
	else:
		_set_status(STATUS_LOCAL.MERGE_AND_MOVE_SINGLE_BRICK)


func _merge_and_move_single_brick():
	print("_merge_and_move_single_block")
	_brick_name = _download_file + str(_current_merging_brick)
	if FileAccess.file_exists(_brick_name) == false:
		_dest_file.close()
		_dest_file = null
		_child_update_msg("ERROR MERGE AN MOVE BLOCK " + _brick_name)
		_reset_info_and_wait()
	else:
		_set_status(STATUS_LOCAL.READ_AND_SAVE)


func _read_and_save():
	print("_read_and_save " + str(_current_merging_brick))
	if _info.compressed == true:
		_input_file_data = FileAccess.open_compressed(
				_brick_name, 
				FileAccess.READ, FileAccess.COMPRESSION_DEFLATE)
	else:
		_input_file_data = FileAccess.open(
				_brick_name,
				FileAccess.READ)
	print("_input_file_data code:" + str(FileAccess.get_open_error()))
	_current_chunk = 0
	_input_file_data_read = false
	_set_status(STATUS_LOCAL.READ_AND_SAVE_ALL_CHUNKS)


func _read_and_save_all_chunks():
	if _input_file_data_read == false:
		_set_status(STATUS_LOCAL.READ_AND_SAVE_GROUP_OF_CHUNKS)
	else:
		_input_file_data.close()
		_input_file_data = null
		_set_status(STATUS_LOCAL.MERGE_AND_MOVE_ALL_BRICKS)


func _read_and_save_group_of_chunks():
	var group_size = 100
	var current_group = 0
	var data_read = null
	while current_group < group_size:
		if _current_chunk > CHUNKSIZE_MULTI:
			_input_file_data_read = true
			break
		if _input_file_data.eof_reached() == true:
			_input_file_data_read = true
			break
		data_read = _input_file_data.get_buffer(CHUNKSIZE)
		_dest_file.store_buffer(data_read)
		current_group += 1
		_current_chunk += 1
	var info ={
		"file_name": _brick_name, 
		"brick": _current_merging_brick,
		"bricks": _info.bricks,
		"chunk": CHUNKSIZE_MULTI - _current_chunk,
		"chunks":  CHUNKSIZE_MULTI,
	}
	_child_update_merge_info(info)
	_set_status(STATUS_LOCAL.READ_AND_SAVE_ALL_CHUNKS)









func _read_and_save_execute(from_file, to_file, msg_info):
	var count = CHUNKSIZE_MULTI
	var data_read = null
	while from_file.eof_reached() == false:
		if count == 0:
			break
		msg_info.block = count
		if (count % 100) == 0:
			_child_update_merge_info(msg_info)
			#await RenderingServer.frame_post_draw
		data_read = from_file.get_buffer(CHUNKSIZE)
		# print(str(count) + "-" + str(data_read.size()))
		to_file.store_buffer(data_read)
		count -= 1


#func _merge_and_move():
#	var dest = null
#	var dir = DirAccess.open(_tmp_dir)
#	var file_name = null
#	var file_data = null
#	var count = 0
#	var msg_info = null
#
#	if _ext == null:
#		dest = FileAccess.open(_destination, FileAccess.WRITE)
#	else:
#		dest = FileAccess.open(_destination + str(_ext), FileAccess.WRITE)
#
#	while true:
#		file_name = _download_file + str(count)
#		msg_info = {
#			"file_name" = file_name,
#			"count" = count,
#			"blocks" = 0,
#			"block" = 0,
#		}
#		print(msg_info)
#		if FileAccess.file_exists(file_name) == false:
#			dest.close()
#			if count < _info.bricks:
#				_child_update_msg("error")
#			else:
#				_child_update_msg("END MERGE")
#			break
#		_child_update_merge_info(msg_info)
#		#await RenderingServer.frame_post_draw
#		if _info.compressed == true:
#			file_data = FileAccess.open_compressed(
#					file_name, 
#					FileAccess.READ, FileAccess.COMPRESSION_DEFLATE)
#		else:
#			file_data = FileAccess.open(file_name, FileAccess.READ)
#		print(FileAccess.get_open_error())
#		## read and write buffer
#		print(file_data.get_error())
#		_read_and_save_start(file_data, dest, msg_info)
#		file_data.close()
#		## remove buffer
##		dir.remove(BUF_NAME + str(count))
#		count += 1

func _merge_and_move_start():
	pass

#func _read_and_save(from_file, to_file, msg_info):
#	var count = CHUNKSIZE_MULTI
#	var data_read = null
#	while from_file.eof_reached() == false:
#		if count == 0:
#			break
#		msg_info.block = count
#		if (count % 100) == 0:
#			_child_update_merge_info(msg_info)
#			#await RenderingServer.frame_post_draw
#		data_read = from_file.get_buffer(CHUNKSIZE)
#		# print(str(count) + "-" + str(data_read.size()))
#		to_file.store_buffer(data_read)
#		count -= 1

func _read_and_save_start(from_file, to_file, msg_info):
	pass


