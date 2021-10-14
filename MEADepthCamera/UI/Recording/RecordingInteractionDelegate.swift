//
//  RecordingInteractionDelegate.swift
//  MEADepthCamera
//
//  Created by Will on 10/13/21.
//
/*
Abstract:
The interaction protocol between TaskListViewController and RecordingListViewController.
*/

protocol RecordingInteractionDelegate: AnyObject {
    /**
     When the recording list view controller has finished an edit, it calls didUpdateRecording for the delegate (the task list view controller) to update the UI.
     
     When deleting a recording, pass nil for recording.
     */
    func didUpdateRecording(_ recording: Recording?, shouldReloadRow: Bool)
    
}
