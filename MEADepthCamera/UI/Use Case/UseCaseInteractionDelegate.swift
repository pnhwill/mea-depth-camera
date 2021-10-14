//
//  UseCaseInteractionDelegate.swift
//  MEADepthCamera
//
//  Created by Will on 9/2/21.
//
/*
Abstract:
The interaction protocol between the presenting ViewController and DetailViewController.
*/

protocol UseCaseInteractionDelegate: AnyObject {
    /**
     When the detail view controller has finished an edit, it calls didUpdateUseCase for the delegate (the presenting view controller) to update the UI.
     
     When deleting a use case, pass nil for use case.
     */
    func didUpdateUseCase(_ useCase: UseCase?, shouldReloadRow: Bool)
    
    /**
     UISplitViewController can show the detail view controller when it is appropriate.
     
     In that case preseting and detail view controllers may not be connected yet.
     
     So in the detail view controller’s willAppear, call this method so that the presenting view controller has a chance to build up the connection.
     */
    //func willShowDetailViewController(_ controller: UseCaseDetailViewController)
}
