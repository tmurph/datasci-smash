    :Author: Trevor Murphy

.. contents::

This repository contains my notes and work applying neural networks to footage from the `Super Smash Bros. Melee <https://en.wikipedia.org/wiki/Super_Smash_Bros._Melee>`_ video game.

So far, I have used transfer learning techniques to train a VGG16-based neural network to classify images of single characters.  See the `classification notebook <classification.ipynb>`_ for details.

Next, I will train a network to locate a character within an image.  Then locate and classify two characters in the same image.

After that, I will train a network to recognize the location and combat move of the characters within the image.

Finally, I hope to make these networks fast enough to run concurrently with streaming video sessions, to enable real time analysis of matches in progress.
