//
//  BeatIndexCardView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 18.7.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import UIKit

class BeatIndexCardViewController: UIViewController, UICollectionViewDelegate {
	
	private let collectionView: UICollectionView = {
		let layout = UICollectionViewFlowLayout()
		let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
		collectionView.translatesAutoresizingMaskIntoConstraints = false
		collectionView.backgroundColor = .darkGray
		return collectionView
	}()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		collectionView.delegate = self
		collectionView.dataSource = self
		collectionView.register(HeadingCell.self, forCellWithReuseIdentifier: "HeadingCell")
		collectionView.register(CardCell.self, forCellWithReuseIdentifier: "CardCell")
		
		view.addSubview(collectionView)
		
		let padding: CGFloat = 16
		collectionView.contentInset = UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
		
		NSLayoutConstraint.activate([
			collectionView.topAnchor.constraint(equalTo: view.topAnchor),
			collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])
	}
}

extension BeatIndexCardViewController: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
	
	func numberOfSections(in collectionView: UICollectionView) -> Int {
	   return 1
   }
	   
   func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
	   return 10 // Number of items you want to display
   }
   
   func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
	   if indexPath.item == 0 {
		   let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "HeadingCell", for: indexPath) as! HeadingCell
		   cell.configure(title: "Section Heading")
		   return cell
	   } else {
		   let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CardCell", for: indexPath) as! CardCell
		   cell.configure(title: "Card asdlfk maseöfl kamseölfk masöldkfm aölekfm  \(indexPath.item)", body: "Card body text is goin on and on and on and still going on and on, from here to eternity and back and forth.", additionalText: "Additional text")
		   return cell
	   }
   }
   
   func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
	   let width = collectionView.bounds.width - collectionView.contentInset.left - collectionView.contentInset.right
	   
	   if indexPath.item == 0 {
		   return CGSize(width: width, height: 50)
	   } else {
		   let desiredWidth = 180.0
		   
		   let fitting = floor((width - 16) / desiredWidth)
		   let cardWidth = (width - (8 * fitting)) / fitting // Adjust the spacing as needed
		   
		   return CGSize(width: cardWidth, height: cardWidth)
	   }
   }
}

class HeadingCell: UICollectionViewCell {
	
	private let titleLabel: UILabel = {
		let label = UILabel()
		label.translatesAutoresizingMaskIntoConstraints = false
		label.font = UIFont.systemFont(ofSize: 20.0, weight: .light)
		label.textColor = .white
		return label
	}()
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		
		contentView.backgroundColor = .none
		contentView.addSubview(titleLabel)
		
		NSLayoutConstraint.activate([
			titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
			titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
			titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
			titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 0)
		])
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func configure(title: String) {
		titleLabel.text = title
	}
}

class CardCell: UICollectionViewCell {
	
	private let headingLabel: UILabel = {
		let label = UILabel()
		label.translatesAutoresizingMaskIntoConstraints = false
		label.font = UIFont.boldSystemFont(ofSize: 18)
		label.numberOfLines = 0
		return label
	}()
	
	private let bodyLabel: UILabel = {
		let label = UILabel()
		label.translatesAutoresizingMaskIntoConstraints = false
		label.font = UIFont.systemFont(ofSize: 16)
		label.numberOfLines = 0
		return label
	}()
	
	private let additionalLabel: UILabel = {
		let label = UILabel()
		label.translatesAutoresizingMaskIntoConstraints = false
		label.font = UIFont.italicSystemFont(ofSize: 14)
		label.textColor = .gray
		return label
	}()
	
	private let stackView: UIStackView = {
		let stackView = UIStackView()
		stackView.translatesAutoresizingMaskIntoConstraints = false
		stackView.axis = .vertical
		stackView.spacing = 8
		return stackView
	}()
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		
		contentView.backgroundColor = .white
		contentView.layer.cornerRadius = 10
		contentView.layer.borderWidth = 1
		contentView.layer.borderColor = UIColor.lightGray.cgColor
		
		stackView.addArrangedSubview(headingLabel)
		stackView.addArrangedSubview(bodyLabel)
		
		contentView.addSubview(stackView)
		contentView.addSubview(additionalLabel)
		
		NSLayoutConstraint.activate([
			stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
			stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
			stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
			stackView.bottomAnchor.constraint(lessThanOrEqualTo: additionalLabel.topAnchor, constant: -8),
			
			additionalLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
			additionalLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
			additionalLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
		])
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func configure(title: String, body: String, additionalText: String) {
		headingLabel.text = title
		bodyLabel.text = body
		additionalLabel.text = additionalText
	}
}
